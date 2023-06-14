local Services  = setmetatable({}, {
    __index = function(self, key)
        return game.GetService(game, key)
    end
})

--=[ Variables ]=--
local Commands = {}
local LocalPlayer = Services.Players.LocalPlayer
local AIChatbot = {
    ChatGPT = {
        Timeout = false,
        Busy = false
    },
    Bard = {
        URL = "https://rest-api-debug.choke.repl.co/api/Bard/conversation/ask",
        Timeout = false,
        Busy = false
    }
}

local Variables = {
    ActivePathfindingID = nil
}
local PermissionDictionary = {
    [5] = "Owner",
    [4] = "Admin",
    [3] = "Trusted",
    [2] = "Whitelisted",
    [1] = "Guest",
    [0] = "Blacklisted"
}

--=[ Internal Functions ]=--
request = request or syn.request or http_request or http.request

--=[ Functions ]=--
local function sayMessage(text, includeBotName, user)
    assert(type(text) == "string", "text must be a string")

    if includeBotName then
        text = "[ " .. getgenv().BlockateBot_Settings.Bot_Name .. " ] " .. text
    end

    if user then
        print(user.Name)
        Services.ReplicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer("/w "..user.Name.." "..text, "All")
    else
        Services.ReplicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(text, "All")
    end
end

local function writeToFile(player, fileName, content)
    local folderName = "./Blockate/Bot/PlayerFiles/"..player.Name
    if not isfolder(folderName) then
        makefolder(folderName)
    end
    writefile(folderName.."/"..fileName, content)
end

local function readFromFile(player, fileName)
    local folderPath = "./Blockate/Bot/PlayerFiles/"..player.Name
    local filePath = folderPath.."/"..fileName
    if isfile(filePath) then
        return readfile(filePath)
    else
        return "File not found!"
    end
end

local function findPlayerByName(name)
    local Players = Services.Players:GetPlayers()
    local searchTerm = string.lower(name)
    local isDisplayNameSearch = true

    if string.sub(searchTerm, 1, 1) == "@" then
        isDisplayNameSearch = false
        searchTerm = string.sub(searchTerm, 2) -- Remove "@" symbol from the search term
    end

    for _, player in ipairs(Players) do
        local playerName = isDisplayNameSearch and player.DisplayName or player.Name
        if string.find(string.lower(playerName), searchTerm) then
            return player
        end
    end
    return nil
end

local function getCommandInfo(commandName)
    local command = Commands[commandName]
    if command then
        local description = command["Description"] or "No description provided."
        local usage = command["Usage"] or "No usage provided."
        return description, usage
    else
        return "Command not found.", ""
    end
end


--=[ Commands ]=--


--=[ Guest Commands ]=--
Commands["help"] = {
    ["Description"] = "Lists info about every command.",
    ["Usage"] = "help (command)",
    ["Permission"] = 1,
    ["Function"] = function(Player, Args)
        -- should only show commands that the player has permission to use, but only list the command name.
        -- if a command is specified, show the description and usage
        -- must not use any newlines or the server will reject the message
        local message = "Available commands for " .. Player.DisplayName .. " (@" .. Player.Name .. "): "
        if Args[1] and not Args[1]:match("^%s*$") then
            local description, usage = getCommandInfo(Args[1])
            message = "Description: " .. description .. " | Usage: " .. usage
            return sayMessage(message, true)
        else
            for commandName, command in pairs(Commands) do
                if command["Permission"] <= getgenv().BlockateBot_Settings.PermissionLevels[Player.UserId] then
                    message = message .. commandName .. ", "
                end
            end
            message = string.sub(message, 1, -3) -- Remove the last comma
            return sayMessage(message, true)
        end
    end
}

Commands["sourcecode"] = {
    ["Description"] = "View the source code for the bot.",
    ["Usage"] = "sourcecode",
    ["Permission"] = 1,
    ["Function"] = function(Player, Args)
        sayMessage("Visit this link in your browser to view the source code: shlink.choke.dev/Blockate_BotSrc", true, Player)
    end
}


--=[ Whitelisted Commands ]=--
Commands["jump"] = {
    ["Permission"] = 2,
    ["Function"] = function(Player, Args)
        sayMessage(Player.DisplayName .. " (@" .. Player.Name .. ") requested me to jump!", true)
        LocalPlayer.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
}

Commands["dance"] = {
    ["Permission"] = 2,
    ["Function"] = function(Player, Args)
        Services.Players:Chat("/e dance")
    end
}

Commands["write"] = {
    ["Description"] = "Writes <textContent> to <fileName>.",
    ["Usage"] = "write <fileName> <textContent>",
    ["Permission"] = 2,
    ["Function"] = function(Player, Args)
        if Args[1] and Args[2] then
            local fileName = Args[1]
            table.remove(Args, 1)
            local content = table.concat(Args, " ")
            writeToFile(Player, fileName, content)
            sayMessage("Successfully wrote to file: " .. fileName, true)
        else
            sayMessage("Please specify a file name and content! Usage: write <fileName> <textContent>", true)
        end
    end
}

Commands["read"] = {
    ["Description"] = "Reads <fileName>.",
    ["Usage"] = "read <fileName>",
    ["Permission"] = 2,
    ["Function"] = function(Player, Args)
        if Args[1] then
            local fileName = Args[1]
            local content = readFromFile(Player, fileName)
            sayMessage("File content for " .. fileName .. ": " .. content, true)
        else
            sayMessage("File not found.", true)
        end
    end
}

Commands["sit"] = {
    ["Description"] = "Sits down.",
    ["Usage"] = "sit",
    ["Permission"] = 2,
    ["Function"] = function(Player, Args)
        LocalPlayer.Character.Humanoid.Sit = true
    end
}

Commands["trip"] = {
    ["Description"] = "Trips.",
    ["Usage"] = "trip",
    ["Permission"] = 2,
    ["Function"] = function(Player, Args)
        LocalPlayer.Character.Humanoid:ChangeState(Enum.HumanoidStateType.FallingDown)
        LocalPlayer.Character.HumanoidRootPart.AssemblyAngularVelocity = Vector3.new(0, 0, math.random(-30, 30))
    end
}

Commands["calculate"] = {
    ["Description"] = "Calculates <expression>.",
    ["Usage"] = "calculate <expression>",
    ["Permission"] = 2,
    ["Function"] = function(Player, Args)
        local expression = table.concat(Args, " ")
        -- Safety checks
        if not expression then
            return sayMessage("Expression was not specified.", true)
        end

        -- Remove any non-numeric and non-operator characters from the expression
        local sanitizedExpression = expression:gsub("[^%d%+%-*/%.()%s]", "")

        -- Check if the sanitized expression is empty
        if sanitizedExpression == "" then
            return sayMessage("Invalid expression", true)
        end

        -- Attempt to load and execute the sanitized expression
        local success, result = pcall(loadstring("return " .. sanitizedExpression))

        -- Check for errors during execution
        if success and type(result) == "number" then
            return sayMessage("Result: " .. result, true)
        else
            return sayMessage("Illegal expression", true)
        end
    end
}

--=[ Trusted Commands ]=--
Commands["follow"] = {
    ["Description"] = "Follows <player>.",
    ["Usage"] = "follow <player>",
    ["Permission"] = 3,
    ["Function"] = function(Player, Args)
        local TargetPlayer = findPlayerByName(Args[1])
        if not Args[1] then
            sayMessage("Player was not specified.", true)
            return
        end

        if not TargetPlayer then
            sayMessage("Player was not found.", true)
            return
        end

        if TargetPlayer == LocalPlayer then
            sayMessage("You cannot follow yourself.", true)
            return
        end

        if getgenv().BlockateBot_Internal.Connections["Follow"] then
            return sayMessage("I am already following someone. Please unfollow them first.", true)
        end

        sayMessage("Now following " .. TargetPlayer.DisplayName .. " (@" .. TargetPlayer.Name .. ").", true)
        local TargetCharacter = TargetPlayer.Character
        local TargetHumanoid = TargetCharacter.Humanoid
        local TargetHumanoidRootPart = TargetCharacter.HumanoidRootPart

        local function follow()
            if not TargetCharacter or not TargetHumanoid or not TargetHumanoidRootPart then
                getgenv().BlockateBot_Internal.Connections["Follow"].Connection:Disconnect()
                getgenv().BlockateBot_Internal.Connections["Follow"] = nil
                return sayMessage("Target player is not alive.", true)
            end

            local TargetPosition = TargetHumanoidRootPart.Position
            local LocalPosition = LocalPlayer.Character.HumanoidRootPart.Position
            local Distance = (TargetPosition - LocalPosition).Magnitude

            if Distance > 50 then
                getgenv().BlockateBot_Internal.Connections["Follow"].Connection:Disconnect()
                getgenv().BlockateBot_Internal.Connections["Follow"] = nil
                return sayMessage("Target player is too far away.", true)
            end

            LocalPlayer.Character.Humanoid:MoveTo(TargetPosition)
        end



        getgenv().BlockateBot_Internal.Connections["Follow"] = {
            ["Connection"] = Services.RunService.Stepped:Connect(follow),
            ["TargetPlayer"] = TargetPlayer
        }
    end
}

Commands["unfollow"] = {
    ["Description"] = "Stops following a player.",
    ["Usage"] = "unfollow",
    ["Permission"] = 3,
    ["Function"] = function(Player, Args)
        if not getgenv().BlockateBot_Internal.Connections["Follow"] then
            sayMessage("I am not following anyone.", true)
            return
        end

        local TargetPlayer = getgenv().BlockateBot_Internal.Connections["Follow"].TargetPlayer

        sayMessage("No longer following " .. TargetPlayer.DisplayName .. " (@" .. TargetPlayer.Name .. ").", true)
        getgenv().BlockateBot_Internal.Connections["Follow"].Connection:Disconnect()
        getgenv().BlockateBot_Internal.Connections["Follow"] = nil
    end
}

Commands["pathfind"] = {
    ["Description"] = "Pathfinds to <player>.",
    ["Usage"] = "pathfind <player>",
    ["Permission"] = 3,
    ["Function"] = function(Player, Args)
        local TargetPlayer = findPlayerByName(Args[1])
        if not Args[1] then
            sayMessage("Player was not specified.", true)
            return
        end

        if not TargetPlayer then
            sayMessage("Player was not found.", true)
            return
        end

        if TargetPlayer == LocalPlayer then
            sayMessage("I cannot pathfind to myself!", true)
            return
        end

        if getgenv().BlockateBot_Internal.Connections["Follow"] then
            sayMessage("I cannot pathfind while following someone. Please unfollow them first.", true)
            return
        end

        -- Generate a GUID for this pathfinding instance
        local GUID = Services.HttpService:GenerateGUID(false)

        sayMessage("Attempting to pathfind to " .. TargetPlayer.DisplayName .. " (@" .. TargetPlayer.Name .. ").", true)

        local PathfindingService = Services.PathfindingService

        local AvoidAttributes = {
            "kill", "warp", "baller", "poisoner", "damager", "tele", "stattele", "teamtele", "timetele", "tripper"
        }
        local PathfindingModifiers = {}
        local function createPathModifier(Parent)
            local PathfindingModifier = Instance.new("PathfindingModifier")
            PathfindingModifier.Label = "AvoidBlock"
            PathfindingModifier.Parent = Parent
            table.insert(PathfindingModifiers, PathfindingModifier)
        end
        
        for _,v in pairs(workspace.Blocks:GetChildren()) do
            for _, attribute in pairs(AvoidAttributes) do
                if not v:FindFirstChild(attribute) then continue end
                createPathModifier(v)
            end
        end

        local Path = PathfindingService:CreatePath({
            AgentCanClimb = true;
            AgentRadius = 3;
            Costs = {
                Climb = 1,
                Jump = 1,
                AvoidBlock = math.huge
            }
        })
        local maxRetries = 3
        local retries = 0
        local blockedPath = false

        Variables.ActivePathfindingID = GUID

        while retries < maxRetries do
            retries = retries + 1
            local startPosition = LocalPlayer.Character.HumanoidRootPart.Position
            local targetPosition = TargetPlayer.Character.HumanoidRootPart.Position
        
            Path:ComputeAsync(startPosition, targetPosition)
            local waypoints = Path:GetWaypoints()
            blockedPath = false
        
            Path.Blocked:Connect(function()
                blockedPath = true
            end)
            
            local LocalGUID = Variables.ActivePathfindingID

            for _, waypoint in pairs(waypoints) do
                if waypoint.Action == Enum.PathWaypointAction.Jump then
                    LocalPlayer.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            
                if blockedPath then
                    sayMessage("No path found. Retrying... Attempt "..retries.."/"..maxRetries, true)
                    continue
                end
            
                LocalPlayer.Character.Humanoid:MoveTo(waypoint.Position)
            
                if Variables.ActivePathfindingID ~= LocalGUID then
                    sayMessage("Pathfinding cancelled.", true)
                    return
                end
            
                LocalPlayer.Character.Humanoid.MoveToFinished:Wait()
            end
        
            -- If the loop completes without getting blocked, break out of the retry loop
            if not blockedPath then
                sayMessage("Pathfinding complete.", true)
                break
            end
        end

        if blockedPath then
            sayMessage("No path found after multiple retries.", true)
        end
        
        for _,v in pairs(workspace.Blocks:GetDescendants()) do
            if not v:IsA("PathfindingModifier") then continue end
            v:Destroy()
        end
    end
}

Commands["reset"] = {
    ["Description"] = "Resets the bot.",
    ["Usage"] = "reset",
    ["Permission"] = 3,
    ["Function"] = function(Player, Args)
        sayMessage("Resetting...", true)
        LocalPlayer.Character.Humanoid.Health = 0
    end
}

Commands["friend"] = {
    -- using setcore, send a friend req
    ["Description"] = "Sends a friend request to <player>.",
    ["Usage"] = "friend <player>",
    ["Permission"] = 3,
    ["Function"] = function(Player, Args)
        local TargetPlayer = findPlayerByName(Args[1])
        if not Args[1] then
            sayMessage("Player was not specified.", true)
            return
        end

        if not TargetPlayer then
            sayMessage("Player was not found.", true)
            return
        end

        if TargetPlayer == LocalPlayer then
            sayMessage("You cannot friend yourself.", true)
            return
        end

        LocalPlayer:RequestFriendship(TargetPlayer)
        sayMessage("Sent a friend request to " .. TargetPlayer.DisplayName .. " (@" .. TargetPlayer.Name .. ").", true)
    end
}

Commands["bard"] = {
    ["Description"] = "Asks Google Bard a question.",
    ["Usage"] = "bard <question>",
    ["Permission"] = 3,
    ["Function"] = function(Player, args)
        -- Check if Bard is busy
        if AIChatbot.Bard.Busy then
          return sayMessage("Google Bard is busy. Please wait.", true)
        end
    
        AIChatbot.Bard.Busy = true
    
        local question = table.concat(args, " ")
    
        local date = DateTime.now()
        date = date:FormatLocalTime("L", "en-us")

        sayMessage("Asking Google Bard...", true)

        local response = request({
            Url = AIChatbot.Bard.URL,
            Method = "POST",
            Headers = {
              ["Content-Type"] = "application/json"
            },
            Body = game:GetService("HttpService"):JSONEncode({
              question = question,
              conversationId = date
            })
        })
    
        local responseTable = game:GetService("HttpService"):JSONDecode(response.Body)
        local responseText = responseTable.data.message
    
        -- Remove any whitespaces from the response text
        responseText = responseText:gsub("%s+", " ")

        -- If the response text is longer than 150 characters, truncate it
        if #responseText > 150 then
          responseText = responseText:sub(1, 147) .. "..."
        end
    
        sayMessage("[ Google Bard ] " .. responseText, false)
    
        AIChatbot.Bard.Busy = false
    end
}

--=[ Admin Commands ]=--
Commands["say"] = {
    ["Description"] = "Says <message>.",
    ["Usage"] = "say <message>",
    ["Permission"] = 4,
    ["Function"] = function(Player, Args)
        if not Args[1] then
            sayMessage("Message was not specified.", true)
            return
        end

        local message = table.concat(Args, " ")
        sayMessage(message, true)
    end
}

--=[ Owner Commands ]=--
Commands["perm"] = {
    ["Description"] = "Sets the <permissionLevel> of <player>.",
    ["Usage"] = "perm <player> <permissionLevel>",
    ["Permission"] = 5,
    ["Function"] = function(Player, Args)
        local TargetPlayer = findPlayerByName(Args[1])
        local permissionLevel = tonumber(Args[2])

        if Args[1] == "all" then
            for _, TargetPlayer in ipairs(Services.Players:GetPlayers()) do
                if TargetPlayer == LocalPlayer then continue end
                getgenv().BlockateBot_Settings.PermissionLevels[TargetPlayer.UserId] = permissionLevel
            end
            sayMessage("Successfully set everyone's permission level to: " .. PermissionDictionary[permissionLevel], true)
            return
        end

        if not Args[1] then
            sayMessage("Player was not specified.", true)
            return
        end

        if not TargetPlayer then
            sayMessage("Player was not found.", true)
            return
        end

        if not permissionLevel then
            sayMessage("Permission level was not specified.", true)
            return
        end

        if permissionLevel < 0 or permissionLevel > 4 then
            sayMessage("Permission level must be between 0 and 4.", true)
            return
        end

        if TargetPlayer == LocalPlayer then
            sayMessage("You cannot change your own permission level.", true)
            return
        end

        local PermissionTable = getgenv().BlockateBot_Settings.PermissionLevels
        local PlayerPermissionLevel = PermissionTable[TargetPlayer.UserId]

        if PlayerPermissionLevel then
            PermissionTable[TargetPlayer.UserId] = permissionLevel
            sayMessage("Successfully updated " .. TargetPlayer.DisplayName .. " (@" .. TargetPlayer.Name .. ")'s permission level to " .. PermissionDictionary[permissionLevel] .. ".", true)
        else
            PermissionTable[TargetPlayer.UserId] = permissionLevel
            sayMessage("Successfully set " .. TargetPlayer.DisplayName .. " (@" .. TargetPlayer.Name .. ")'s permission level to: " .. PermissionDictionary[permissionLevel] .. ".", true)
        end
        sayMessage("Type .help to see the commands you have access to.", true)
    end
}

Commands["update"] = {
    ["Description"] = "Updates the bot's commands file.",
    ["Usage"] = "update",
    ["Permission"] = 5,
    ["Function"] = function(Player, Args)
        sayMessage("Updating...", true)
        CommandsTable = getgenv().BlockateBot_Settings.DevMode and loadstring(readfile(getgenv().BlockateBot_Settings.Commands_FilePath))() or loadstring(game:HttpGet("https://raw.githubusercontent.com/choke-dev/scripts/main/Blockate/BlockBot/Commands.lua"))()
    end
}

Commands["stop"] = {
    ["Description"] = "Stops the bot.",
    ["Usage"] = "stop",
    ["Permission"] = 5,
    ["Function"] = function(Player, Args)
        sayMessage("Stopping...", true)
        for _, Connection in pairs(getgenv().BlockateBot_Internal.Connections) do
            Connection:Disconnect()
        end
        sayMessage("Stopped.", true)
    end
}

return Commands
