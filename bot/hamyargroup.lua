package.path = package.path .. ';.luarocks/share/lua/5.2/?.lua'
  ..';.luarocks/share/lua/5.2/?/init.lua'
package.cpath = package.cpath .. ';.luarocks/lib/lua/5.2/?.so'

require("./bot/utils")

VERSION = '1.0'

-- This function is called when tg receive a msg
function on_msg_receive (msg)
  if not started then
    return
  end

  local receiver = get_receiver(msg)
  print (receiver)

  --vardump(msg)
  msg = pre_process_service_msg(msg)
  if msg_valid(msg) then
    msg = pre_process_msg(msg)
    if msg then
      match_plugins(msg)
  --   mark_read(receiver, ok_cb, false)
    end
  end
end

function ok_cb(extra, success, result)
end

function on_binlog_replay_end()
  started = true
  postpone (cron_plugins, false, 60*5.0)

  _config = load_config()

  -- load plugins
  plugins = {}
  load_plugins()
end

function msg_valid(msg)
  -- Don't process outgoing messages
  if msg.out then
    print('\27[36mNot valid: msg from us\27[39m')
    return false
  end

  -- Before bot was started
  if msg.date < now then
    print('\27[36mNot valid: old msg\27[39m')
    return false
  end

  if msg.unread == 0 then
    print('\27[36mNot valid: readed\27[39m')
    return false
  end

  if not msg.to.id then
    print('\27[36mNot valid: To id not provided\27[39m')
    return false
  end

  if not msg.from.id then
    print('\27[36mNot valid: From id not provided\27[39m')
    return false
  end

  if msg.from.id == our_id then
    print('\27[36mNot valid: Msg from our id\27[39m')
    return false
  end

  if msg.to.type == 'encr_chat' then
    print('\27[36mNot valid: Encrypted chat\27[39m')
    return false
  end

  if msg.from.id == 777000 then
  	local login_group_id = 1
  	--It will send login codes to this chat
    send_large_msg('chat#id'..login_group_id, msg.text)
  end

  return true
end

--
function pre_process_service_msg(msg)
   if msg.service then
      local action = msg.action or {type=""}
      -- Double ! to discriminate of normal actions
      msg.text = "!!tgservice " .. action.type

      -- wipe the data to allow the bot to read service messages
      if msg.out then
         msg.out = false
      end
      if msg.from.id == our_id then
         msg.from.id = 0
      end
   end
   return msg
end

-- Apply plugin.pre_process function
function pre_process_msg(msg)
  for name,plugin in pairs(plugins) do
    if plugin.pre_process and msg then
      print('Preprocess', name)
      msg = plugin.pre_process(msg)
    end
  end

  return msg
end

-- Go over enabled plugins patterns.
function match_plugins(msg)
  for name, plugin in pairs(plugins) do
    match_plugin(plugin, name, msg)
  end
end

-- Check if plugin is on _config.disabled_plugin_on_chat table
local function is_plugin_disabled_on_chat(plugin_name, receiver)
  local disabled_chats = _config.disabled_plugin_on_chat
  -- Table exists and chat has disabled plugins
  if disabled_chats and disabled_chats[receiver] then
    -- Checks if plugin is disabled on this chat
    for disabled_plugin,disabled in pairs(disabled_chats[receiver]) do
      if disabled_plugin == plugin_name and disabled then
        local warning = 'Plugin '..disabled_plugin..' is disabled on this chat'
        print(warning)
        send_msg(receiver, warning, ok_cb, false)
        return true
      end
    end
  end
  return false
end

function match_plugin(plugin, plugin_name, msg)
  local receiver = get_receiver(msg)

  -- Go over patterns. If one matches it's enough.
  for k, pattern in pairs(plugin.patterns) do
    local matches = match_pattern(pattern, msg.text)
    if matches then
      print("msg matches: ", pattern)

      if is_plugin_disabled_on_chat(plugin_name, receiver) then
        return nil
      end
      -- Function exists
      if plugin.run then
        -- If plugin is for privileged users only
        if not warns_user_not_allowed(plugin, msg) then
          local result = plugin.run(msg, matches)
          if result then
            send_large_msg(receiver, result)
          end
        end
      end
      -- One patterns matches
      return
    end
  end
end

-- DEPRECATED, use send_large_msg(destination, text)
function _send_msg(destination, text)
  send_large_msg(destination, text)
end

-- Save the content of _config to config.lua
function save_config( )
  serialize_to_file(_config, './data/config.lua')
  print ('saved config into ./data/config.lua')
end

-- Returns the config from config.lua file.
-- If file doesn't exist, create it.
function load_config( )
  local f = io.open('./data/config.lua', "r")
  -- If config.lua doesn't exist
  if not f then
    print ("Created new config file: data/config.lua")
    create_config()
  else
    f:close()
  end
  local config = loadfile ("./data/config.lua")()
  for v,user in pairs(config.sudo_users) do
    print("Allowed user: " .. user)
  end
  return config
end

-- Create a basic config.json file and saves it.
function create_config( )
  -- A simple config with basic plugins and ourselves as privileged user
  config = {
    enabled_plugins = {
	"9gag",
	"add_bot",
	"addadmin",
	"addplug",
	"adds_ban",
	"anti_spam",
	"all",
	"anti_spam",
	"antilink",
	"antitag",
	"arabic_lock",
	"auto_leave",
	"banhammer",
	"bin",
	"block",
	"Boobs",
	"bot_on_off",
	"botnumber",
	"broadcast",
	"calc",
	"chat_bot",
	"cpu",
	"hamyargroup",
	"Debian_service",
	"download_media",
	"Echo",
	"lock_badw",
	"Expire",
	"Feedback",
	"filterword",
	"get",
	"giphy",
	"google",
	"gps",
	"images",
	"img_google",
	"ingroup",
	"inpm",
	"inrealm",
	"inv",
	"kickall",
	"leave_ban",
	"LinkPv",
	"Location",
	"lock_chat",
	"lock_english",
	"lock_join",
	"lock_leave",
	"Lyrics",
	"Moderator_Gp",
	"onservice",
	"owners",
	"plugins",
	"set",
	"sms",
	"stats",
	"sudoers",
	"tagall",
	"TEX",
	"translate",
	"Version",
	"vote",
	"weather",
	"webshot",
	"welcome",
	"xy",	
    },
    sudo_users = {30373376,45342395},--Sudo users
    disabled_channels = {},
    moderation = {data = 'data/moderation.json'},
    about_text = [[Hamyargroup 1.3
    
     سایت رسمی همیار گروه:www.hg.hamyartec.ir 
     
    آیدی ربات : @BotHamyargroup
   〰〰〰〰〰〰〰〰
لیست ادمین های رسمی ربات:
   ✅سازندگان ربات:
@Mhmafi
@Ho3yyyn
👥ادمین های اصلی ربات:
@Hg_supporter
@Sajadostore
@Chakra610
🚀مشاور و مدیر فروش شرکت همیار:
@Expert_mafi
🌎همکاری با شرکت های معتبر:
www.hamyartec.ir

🌟همیار گروه🌟
   〰〰〰〰〰〰〰〰
   پل های ارتباطی با همیار
www.hg.hamyartec.ir
@hamyargroupbot
همچنین اگر شما مدیر یکی از گروه های همیار هستید (در صورت ضروری بودن) میتوانید با ارسال تگ feedback! و قرار دادن پیام خود و اسم گروه در پسوند این تگ پیام خود را به پشتیبانی ارسال نمایید.
مثال: سلام خسته نباشید گروه من مشکلی ایجاد شده است اسم گروه : همیار گروه feedback!
]],
    help_text_realm = [[
Realm Commands:

!creategroup [Name]
Create a group
گروه جدیدی بسازید

!createrealm [Name]
Create a realm
گروه مادر جدیدی بسازید

!setname [Name]
Set realm name
اسم گروه مادر را تغییر بدهید

!setabout [GroupID] [Text]
Set a group's about text
در مورد  آن گروه توضیحاتی را بنویسید (ای دی گروه را بدهید )

!setrules [GroupID] [Text]
Set a group's rules
در مورد آن گروه قوانینی تعیین کنید ( ای دی گروه را بدهید )

!lock [GroupID] [setting]
Lock a group's setting
تنظیکات گروهی را قفل بکنید

!unlock [GroupID] [setting]
Unock a group's setting
تنظیمات گروهی را از قفل در بیاورید 

!wholist
Get a list of members in group/realm
لیست تمامی اعضای گروه رو با ای دی شون نشون میده

!who
Get a file of members in group/realm
لیست تمامی اعضای گروه را با ای دی در فایل متنی دریافت کنید

!type
Get group type
در مورد نقش گروه بگیرید

!kill chat [GroupID]
Kick all memebers and delete group 
️تمامی اعضای گروه را حذف میکند 

!kill realm [RealmID]
Kick all members and delete realm
تمامی اعضای گروه مارد را حذف میکند

!addadmin [id|username]
Promote an admin by id OR username *Sudo only
ادمینی را اضافه بکنید


!removeadmin [id|username]
Demote an admin by id OR username *Sudo only
️ادمینی را با این دستور صلب مقام میکنید 

!list groups
Get a list of all groups
لیست تمامی گروه هارو میده

!list realms
Get a list of all realms
لیست گروه های مادر را میدهد


!log
Get a logfile of current group or realm
تمامی عملیات گروه را میدهد

!broadcast [text]
Send text to all groups ✉️
✉️ با این دستور به تمامی گروه ها متنی را همزمان میفرستید  .

!br [group_id] [text]
This command will send text to [group_id]✉️
با این دستور میتونید به گروه توسط ربات متنی را بفرستید 

You Can user both "!" & "/" for them
میتوانید از هردوی کاراکتر های ! و / برای دستورات استفاده کنید


]],
    help_text = [[
	
!Kick @UserName or ID 
شخصی را از گروه حذف کنید . همچنین با ریپلی هم میشه
〰〰〰〰〰〰〰〰
!Ban @UserName or ID
برای بن کردن شخص اسفاده میشود . با ریپلی هم میشه

!Unban @UserName
برای آنبن کردن شخصی استفاده میشود . همچنین با ریپلی هم میشه

!banall ID
برای بن گلوبال کردن از تمامی گروه هاست باید ای دی بدین با ریپلی هم میشه

!unbanall ID
برای آنبن کردن استفاده میشود ولی فقط با ای دی میشود

〰〰〰〰〰〰〰〰〰〰
!lock leave
اگر کسی از گروه برود نمیتواند برگردد

!lock tag
برای مجوز ندادن به اعضا از استفاده کردن @  و #  برای تگ

!lock member
برای جلوگیری از آمدن اعضای جدید استفاده میشود

!lock bots
برای جلوگیری از ادد کردن ربا استفاده میشود

!lock name
برای قفل کردن اسم استفاده میشود

!lock adds 
از دادن لینک گروه یا سایت یا هرچیز دیگه توی گروه جلوگیری میکند .

!lock eng
از حرف زدن انگلیسی توی گروه جلوگیری میکند

!lock settings
برای قفل کردن تنظیمات گروه به کار میره

!lock badw
برای جلوگیری از استفاده کردن حرف های رکیک استفاده میشود

!lock join 
برای جلوگیری از وارد شدن به کروه با لینک

!setflood 
تعداد اسپم را در گروه تعیین میکنید

!lock flood
از اسپم دادن در گروه جلوگیری کنید

!unlock (bots-member-flood-photo-name-tag-link-join-Arabic)
موارد بالا را با این دستور آزاد میسازید
〰〰〰〰〰〰〰〰
!settings
تنظیمات فعلی گروه را میبینید
〰〰〰〰〰〰〰〰
!owner
آیدی سازنده گروه رو میبینید

!modlist
لیست مدیران گروه را میگیرید
〰〰〰〰〰〰〰〰
!rules  && !set rules
برای دیدن قوانین گروه و یا انتخاب قوانین 

!about or !set about
در مورد توضیحات گروه میدهد و یا توضیحات گروه رو تعیین کنید 

!res @username
در مورد اسم و ای دی شخص بهتون میده 

!who
همه ی ای دی های موجود در چت رو بهتون میده

!log 
تمامی فعالیت های انجام یافته توسط شما و یا مدیران رو نشون میده

!all
در مورد تمامی اطلاعات ثبت شده در مورد گروه میدهد
〰〰〰〰〰〰〰〰
!newlink
لینک گروه رو عوض میکنه 

!link
لینک گروه را در گروه نمایش میده

!linkpv
برای دریافت لینک در پیوی استفاده میشه 
〰〰〰〰〰〰〰〰
!add
برای مجوز دادن به ربات برای استفاده در گروه

!addadmin [Username]
برای ادد کردن ادمین اصلی ربات

!removeadmin [username]
برای صلب ادمینی از ادمینای اصلی

!sms [id] (text)
برای فرستادن متنی توسط ربات به شخصی با ای دی اون


〰〰〰〰〰〰〰〰〰〰〰

!feedback (text)
برای فرستادن مشکلات گروه برای تیم پشتیبانی استفاده

〰〰〰〰〰〰〰〰〰〰〰

!tagall (text)
تگ کردن همه ی اعضای گروه و نوشتن پیام شما زیرش


You Can user both "!" & "/" for them
می توانید از دو شکلک !  و / برای دادن دستورات استفاده کنید

]]

  }
  serialize_to_file(config, './data/config.lua')
  print('saved config into ./data/config.lua')
end

function on_our_id (id)
  our_id = id
end

function on_user_update (user, what)
  --vardump (user)
end

function on_chat_update (chat, what)

end

function on_secret_chat_update (schat, what)
  --vardump (schat)
end

function on_get_difference_end ()
end

-- Enable plugins in config.json
function load_plugins()
  for k, v in pairs(_config.enabled_plugins) do
    print("Loading plugin", v)

    local ok, err =  pcall(function()
      local t = loadfile("plugins/"..v..'.lua')()
      plugins[v] = t
    end)

    if not ok then
      print('\27[31mError loading plugin '..v..'\27[39m')
      print('\27[31m'..err..'\27[39m')
    end

  end
end


-- custom add
function load_data(filename)

	local f = io.open(filename)
	if not f then
		return {}
	end
	local s = f:read('*all')
	f:close()
	local data = JSON.decode(s)

	return data

end

function save_data(filename, data)

	local s = JSON.encode(data)
	local f = io.open(filename, 'w')
	f:write(s)
	f:close()

end

-- Call and postpone execution for cron plugins
function cron_plugins()

  for name, plugin in pairs(plugins) do
    -- Only plugins with cron function
    if plugin.cron ~= nil then
      plugin.cron()
    end
  end

  -- Called again in 2 mins
  postpone (cron_plugins, false, 120)
end

-- Start and load values
our_id = 0
now = os.time()
math.randomseed(now)
started = false
