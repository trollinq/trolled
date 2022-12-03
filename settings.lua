do
	local flags = library.flags;
	local options = library.options;

	settings = menu:AddTab("Settings"); do 
		local theme_section = settings:AddSection("Theme", 1); do
			local theme_strings = {"Custom"};
			for _, v in next, library.themes do
				table.insert(theme_strings, v.name);
			end;
			local setByPreset = false;

			theme_section:AddList({text = "Presets", flag = "preset_theme", values = theme_strings, callback = function(new_theme)
				if new_theme == "Custom" then return end
				setByPreset = true
				for _,v in next, library.themes do
					if v.name == new_theme then
						for x, d in pairs(library.options) do
							if v.theme[tostring(x)] ~= nil then
								d:SetColor(v.theme[tostring(x)]);
							end;
						end;
						library:SetTheme(v.theme);
						break;
					end;
				end;
				setByPreset = false
			end}):Select("Default");

			for i, v in pairs(library.theme) do
				theme_section:AddColor({text = i, flag = i, color = library.theme[i], callback = function(c3)
					library.theme[i] = c3;
					library:SetTheme(library.theme);
					if not setByPreset then 
						library.options.preset_theme:Select("Custom");
					end;
				end});
			end;
		end;
		-- 
		local configuration_section = settings:AddSection("Configuration", 2); do
			local function refresh_configs()
				options.selected_config:ClearValues();
				for _,v in next, listfiles(library.cheatname .."/" .. library.gamename .. "/configs") do
					local ext = "."..v:split(".")[#v:split(".")];
					if ext == library.fileext then
						options.selected_config:AddValue(v:split("\\")[#v:split("\\")]:sub(1,-#ext-1))
					end
				end
			end

			configuration_section:AddBox({text = "Config Name", flag = "configinput"})
			configuration_section:AddList({text = "Config", flag = "selected_config"})
			configuration_section:AddButton({text = "Load", confirm = true, callback = function()
				if flags.selected_config then
					library:LoadConfig(flags.selected_config);
					return
				end
				library:LoadConfig(flags.configinput);
			end});
			configuration_section:AddButton({text = "Save", confirm = true, callback = function()
				if flags.selected_config then
					library:SaveConfig(flags.selected_config);
					return
				end
				library:SaveConfig(flags.configinput);
			end});
			configuration_section:AddButton({text = "Create", confirm = true, callback = function()
				if library:GetConfig(flags.configinput) then
					library:SendNotification("Config \""..flags.configinput.."\" already exists.", 5, Color3.new(1,0,0));
					return
				end
				local s,e = pcall(function()
					local cfg = {};
					for flag,option in next, library.options do
						if option.class == 'toggle' then
							cfg[flag] = option.state;
						elseif option.class == 'slider' then
							cfg[flag] = option.value;
						elseif option.class == 'bind' then
							cfg[flag] = option.bind.Name;
						elseif option.class == 'color' then
							cfg[flag] = {
								option.color.r,
								option.color.g,
								option.color.b,
								option.trans,
							}
						elseif option.class == 'list' then
							cfg[flag] = option.selected;
						end
					end
					writefile(library.cheatname..'/'..library.gamename..'/configs/'..flags.configinput..library.fileext, game:GetService("HttpService"):JSONEncode(cfg));
				end)

				if s then
					library:SendNotification('Successfully saved config: '..flags.configinput, 5, Color3.new(0,1,0));
				else
					library:SendNotification('Error saving config: '..tostring(e)..'. ('..tostring(flags.configinput)..')', 5, Color3.new(1,0,0));
				end

				refresh_configs();
			end})
			configuration_section:AddButton({text = "Delete", confirm = true, callback = function()
				if library:GetConfig(flags.selectedconfig) then
					delfile(library.cheatname.."/"..library.gamename.."/configs/"..flags.selectedconfig.. library.fileext);
					refresh_configs();
				end;
			end});
			configuration_section:AddButton({text = "Refresh", callback = function()
				refresh_configs();
			end});
			refresh_configs();
		end;
		--
		local scripts_section = settings:AddSection("Scripts", 2); do
			local function refresh_scripts()
				options.selected_script:ClearValues();
				for _,v in next, listfiles(library.cheatname .."/" .. library.gamename .. "/scripts") do
					local ext = "."..v:split(".")[#v:split(".")];
					if ext == ".lua" then
						options.selected_script:AddValue(v:split("\\")[#v:split("\\")]:sub(1,-#ext-1))
					end
				end
			end

			scripts_section:AddList({text = "Script", flag = "selected_script"})
			scripts_section:AddButton({text = "Load", confirm = true, callback = function()
				loadfile(library.cheatname.."/"..library.gamename.."/scripts/"..flags.selected_script.. ".lua")();
			end});
			scripts_section:AddButton({text = "Delete", confirm = true, callback = function()
				if library:GetConfig(flags.selected_script) then
					delfile(library.cheatname.."/"..library.gamename.."/scripts/"..flags.selected_script.. ".lua");
					refresh_scripts();
				end;
			end});
			scripts_section:AddButton({text = "Refresh", callback = function()
				refresh_scripts();
			end});
			refresh_scripts();
		end;
		-- 
		local main_section = settings:AddSection("Main", 2); do
			main_section:AddBind({text = "Open / Close", flag = "togglebind", nomouse = true, noindicator = true, bind = Enum.KeyCode.End, callback = function()
				library:SetOpen(not library.open)
			end});
			main_section:AddButton({text = "Copy Server Connect Script", callback = function()
				setclipboard(([[game:GetService("TeleportService"):TeleportToPlaceInstance(%s, "%s")]]):format(game.PlaceId, game.JobId));
			end});
			main_section:AddButton({text = "Rejoin Game", confirm = true, callback = function()
				game:GetService("TeleportService"):Teleport(game.PlaceId);
			end})
			if getgenv().unloadEnabled then
				main_section:AddButton({text = "Unload",  callback = function()
					pcall(library.Unload,library)
					pcall(function()library.unloadSignal:Fire()end)
				end});
			end
			main_section:AddBox({text = "Cheat Name", flag = "cheat_name", input = library.cheatname, callback = function(txt)
				library.change_name(txt, flags.cheat_domain);
			end});
			main_section:AddBox({text = "Cheat Domain", flag = "cheat_domain", input = library.domain, callback = function(txt)
				library.change_name(flags.cheat_name, txt);
			end});
		end;
	end;
end

do
	local Start, FrameUpdateTable, LastIteration=os.clock(), {}, nil

	library.watermark.lock="Top Left"
	library.watermark.text[5][2]=false
	library.flags.watermark_enabled=not library.flags.watermark_enabled
	local watermark_section=settings:AddSection("Watermark", 1); do
		watermark_section:AddToggle({flag="watermarktoggle",state=true,text="Watermark Toggle",callback=function(bool)
			pcall(function()
				library.flags.watermark_enabled=bool
			end)
		end})

		watermark_section:AddList({text="Watermark Position", flag="watermark_pos", values={"Top Left", "Top Right", "Top", "Bottom Left", "Bottom Right"}, callback=function(new_pos)
			library.watermark.lock=new_pos
		end}):Select("Top Left")
	end

	Start=os.clock()
	task.spawn(handleTab,settings,true)
	game:GetService("RunService").Heartbeat:Connect(function()
		task.spawn(function()
			for i,v in pairs(esp.players) do
				v.FillColor=library.flags.playerEspColor1
				v.OutlineColor=library.flags.playerEspColor2
				v.FillTransparency=library.options.playerEspColor1.trans
				v.OutlineTransparency=library.options.playerEspColor2.trans--(library.flags.espOutlines and 0) or 1
			end

			for i,v in pairs(esp.shark) do
				v.FillColor=library.flags.sharkEspColor1
				v.OutlineColor=library.flags.sharkEspColor2
				v.FillTransparency=library.options.sharkEspColor1.trans
				v.OutlineTransparency=library.options.sharkEspColor2.trans--(library.flags.espOutlines and 0) or 1
			end
		end)

		LastIteration=os.clock()
		for Index=#FrameUpdateTable, 1, -1 do
			FrameUpdateTable[Index + 1]=FrameUpdateTable[Index] >= LastIteration - 1 and FrameUpdateTable[Index] or nil
		end

		FrameUpdateTable[1]=LastIteration
		pcall(function()
			library.stats.fps=math.floor(os.clock() - Start >= 1 and #FrameUpdateTable or #FrameUpdateTable / (os.clock() - Start))
			task.spawn(library.watermark.Update, library.watermark)
		end)
	end)
end
