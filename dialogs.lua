local InputDialog = require("ui/widget/inputdialog")
local ChatGPTViewer = require("chatgptviewer")
local UIManager = require("ui/uimanager")
local InfoMessage = require("ui/widget/infomessage")
local _ = require("gettext")

local queryChatGPT = require("gpt_query")

local CONFIGURATION = nil
local buttons, input_dialog

local success, result = pcall(function() return require("configuration") end)
if success then
  CONFIGURATION = result
else
  print("configuration.lua not found, skipping...")
end

local function isStringEmptyOrNil(str)
    return str == nil or str == ""
end

local function translateText(text, target_language)
  local translation_message = {
    role = "user",
    content = "Translate the following text to " .. target_language .. ": " .. text
  }
  local translation_history = {
    {
      role = "system",
      content = "You are a helpful translation assistant. Provide direct translations without additional commentary. make it clear, understandable, and as natural as possible like native."
    },
    translation_message
  }
  return queryChatGPT(translation_history)
end


local function summaryText(text, target_language)
  local target_language_isNullOrEmpty = isStringEmptyOrNil(target_language)
  local content = ""
  if target_language_isNullOrEmpty then
        content = "Create a concise summary capturing the key points of this text: " .. text
  else 
        content = "Create a concise summary in " .. target_language .. " language: " .. text
  end
  
  local summary_message = {
    role = "user",
    content = content
  }
  local summary_history = {
    {
      role = "system",
      content = "Create clear and concise summaries focusing on essential information only."
    },
    summary_message
  }
  return queryChatGPT(summary_history)
end

local function createResultText(highlightedText, message_history)
  local result_text = _("Highlighted text: ") .. "\"" .. highlightedText .. "\"\n\n"

  for i = 3, #message_history do
    if message_history[i].role == "user" then
      result_text = result_text .. _("User: ") .. message_history[i].content .. "\n\n"
    else
      result_text = result_text .. _("ChatGPT: ") .. message_history[i].content .. "\n\n"
    end
  end

  return result_text
end

local function showLoadingDialog()
  local loading = InfoMessage:new{
    text = _("Loading..."),
    timeout = 0.1
  }
  UIManager:show(loading)
end

local function showChatGPTDialog(ui, highlightedText, message_history)
  local title, author =
    ui.document:getProps().title or _("Unknown Title"),
    ui.document:getProps().authors or _("Unknown Author")
  local message_history = message_history or {{
    role = "system",
    content = "The following is a conversation with an AI assistant. The assistant is helpful, creative, clever, and very friendly. Answer as concisely as possible."
  }}

  local function handleNewQuestion(chatgpt_viewer, question)
    table.insert(message_history, {
      role = "user",
      content = question
    })

    local answer = queryChatGPT(message_history)

    table.insert(message_history, {
      role = "assistant",
      content = answer
    })

    local result_text = createResultText(highlightedText, message_history)

    chatgpt_viewer:update(result_text)
  end

  buttons = {
    {
      text = _("Cancel"),
      callback = function()
        UIManager:close(input_dialog)
      end
    },
    {
      text = _("Ask"),
      callback = function()
        local question = input_dialog:getInputText()
        UIManager:close(input_dialog)
        showLoadingDialog()

        UIManager:scheduleIn(0.1, function()
          local context_message = {
            role = "user",
            content = "I'm reading something titled '" .. title .. "' by " .. author ..
              ". I have a question about the following highlighted text: " .. highlightedText
          }
          table.insert(message_history, context_message)

          local question_message = {
            role = "user",
            content = question
          }
          table.insert(message_history, question_message)

          local answer = queryChatGPT(message_history)
          local answer_message = {
            role = "assistant",
            content = answer
          }
          table.insert(message_history, answer_message)

          local result_text = createResultText(highlightedText, message_history)

          local chatgpt_viewer = ChatGPTViewer:new {
            title = _("AskGPT"),
            text = result_text,
            onAskQuestion = handleNewQuestion
          }

          UIManager:show(chatgpt_viewer)
        end)
      end
    }
  }

  if CONFIGURATION and CONFIGURATION.features and CONFIGURATION.features.translate_to then
    table.insert(buttons, {
      text = _("Translate"),
      callback = function()
        showLoadingDialog()

        UIManager:scheduleIn(0.1, function()
          local translated_text = translateText(highlightedText, CONFIGURATION.features.translate_to)

          table.insert(message_history, {
            role = "user",
            content = "Translate to " .. CONFIGURATION.features.translate_to .. ": " .. highlightedText
          })

          table.insert(message_history, {
            role = "assistant",
            content = translated_text
          })

          local result_text = createResultText(highlightedText, message_history)
          local chatgpt_viewer = ChatGPTViewer:new {
            title = _("Translation"),
            text = result_text,
            onAskQuestion = handleNewQuestion
          }

          UIManager:show(chatgpt_viewer)
        end)
      end
    })
  end


  if CONFIGURATION and CONFIGURATION.features and (CONFIGURATION.features.summary==true) then
    table.insert(buttons, {
      text = _("Summary"),
      callback = function()
        showLoadingDialog()

        UIManager:scheduleIn(0.1, function()
          local summary_text = summaryText(highlightedText, CONFIGURATION.features.translate_to)

          table.insert(message_history, {
            role = "user",
            content = "Summary of: " .. highlightedText
          })

          table.insert(message_history, {
            role = "assistant",
            content = summary_text
          })

          local result_text = createResultText(highlightedText, message_history)
          local chatgpt_viewer = ChatGPTViewer:new {
            title = _("Summary"),
            text = result_text,
            onAskQuestion = handleNewQuestion
          }

          UIManager:show(chatgpt_viewer)
        end)
      end
    })
    end

  input_dialog = InputDialog:new{
    title = _("Ask a question about the highlighted text"),
    input_hint = _("Type your question here..."),
    input_type = "text",
    buttons = {buttons}
  }
  UIManager:show(input_dialog)
end

return showChatGPTDialog
