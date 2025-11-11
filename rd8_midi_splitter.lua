ardour { 	
			["type"] = "EditorAction", 
			name = "RD8 MIDI Splitter", 
			license = "MIT",
			author = "dotted_pi",
			description = [[This script exports the selected RD8 instruments to their own unique tracks from a MIDI master track.]] 
		}

function factory () return function ()

	-----------------------------------------------------------------------------------
	--set up the RD8 class containing all instruments with their midi notes and names--
	-----------------------------------------------------------------------------------

	local rd8 = {

		{inst = "kick", note = 36, name = "Kick"},

		{inst = "snare", note = 40, name = "Snare"},

		{inst = "low_ct", note = 45, name = "Low Conga/Tom"},

		{inst = "mid_ct", note = 47,  name = "Mid Conga/Tom"},

		{inst = "high_ct", note = 50,  name = "High Conga/Tom"},

		{inst = "cl_rs", note = 37,  name = "Claves/Rim Shot"},

		{inst = "clap", note = 39,  name = "Maracas/Claps"},

		{inst = "cowbell", note = 56,  name = "Cowbell"},

		{inst = "cymbal", note = 51,  name = "Cymbal"},

		{inst = "openhat", note = 46,  name = "Open Hat"},

		{inst = "closedhat", note = 42,  name = "Closed Hat"},

	}

	------------------------------------------------------------------------------------
	-- check for RD8_MIDI_Master track and select the first instance if multiple exist--
	------------------------------------------------------------------------------------

	local rd8_midi_master_found = false
	local rd8_track_name = "RD8_MIDI_Master" 	-- the exact name of the MIDI Master track to match 
	local rd8_midi_master_track = nil

	for track in Session:get_tracks():iter() do -- iterate over all tracks in the session
		if (string.find(track:name(), rd8_track_name) and track:data_type():to_string() == "midi") then --check if valid RD8_MIDI_Master exists
			rd8_midi_master_found = true							
			rd8_midi_master_track = track:to_track():to_midi_track()						--and select the first valid option
			--print(tostring(rd8_midi_master_track:get_playback_channel_mode()))					--and select the first valid option
			--print(string.format("%x",rd8_midi_master_track:get_playback_channel_mask()))
		end
		break
	end

	if not rd8_midi_master_found then
		LuaDialog.Message ("Error", "No valid 'RD8_MIDI_Master' track could be found!", LuaDialog.MessageType.Error, LuaDialog.ButtonType.Close):run()
		goto script_end
	end

	-------------------------------------------
	--create setup dialog and save user input--
	-------------------------------------------
	
	local dialog_options = {}

	table.insert(dialog_options, { type = "label", title = "Select instruments for creating their unique MIDI track.\nThis will filter the RD8_MIDI_Master track for the \nrespective instrument and copy MIDI events."})
	for rd8_inst_number, rd8_inst in pairs(rd8) do
		table.insert(dialog_options, { type = "checkbox", key = "onoff_"..rd8_inst["inst"], default = false, title = tostring(rd8_inst_number).." "..rd8_inst["name"]})	
	end

	table.insert(dialog_options,{ type = "label", title = "Ticking the following checkbox will send each instrument \nto the MIDI channel number indicated next to its name. NOT WORKING YET" })
	table.insert(dialog_options,{ type = "checkbox", key = "onoff_separate_channels", default = false, title = "Seperate MIDI-Channels"})

	local od = LuaDialog.Dialog("RD8 MIDI Splitter Setup", dialog_options)
	local rv = od:run()

	--if rv:isnil() then goto script_end end

	----------------------------------------------------------
	--create the new tracks and populate with filtered notes--
	----------------------------------------------------------

	local cur_inst_tracklist = nil

	for rd8_inst_id, rd8_inst in pairs(rd8) do
		if rv["onoff_"..rd8_inst["inst"]] then
			--print(rd8_inst["name"])	--debug point
			
			cur_inst_tracklist = Session:new_midi_track (ARDOUR.ChanCount(ARDOUR.DataType ("midi"), 1),  ARDOUR.ChanCount(ARDOUR.DataType ("midi"), 1), false, ARDOUR.PluginInfo(), nil, nil, 1, "RD8_MIDI_"..rd8_inst["name"].."("..tostring(rd8_inst_id)..")", ARDOUR.PresentationInfo.max_order, ARDOUR.TrackMode.Normal)
			
			for cur_track in cur_inst_tracklist:iter() do
				--print(cur_track:name()) --debug point
				
				for region in rd8_midi_master_track:playlist():region_list():iter() do  
					
					if region:isnil() then break end
				
					local new_region = ARDOUR.RegionFactory.clone_region(region, true, true):to_midiregion() 
					
					local midi_model = region:to_midiregion():midi_source(0):model()				
					local midi_command = midi_model:new_note_diff_command("Filter MIDI Events")

					local cur_model = new_region:midi_source(0):model()
					local cur_command = cur_model:new_note_diff_command("Write MIDI Events")
					
					for note in ARDOUR.LuaAPI.note_list (midi_model):iter() do
						if note:note() == rd8_inst["note"] then
							local channel = note:channel()					--set note:channel() if seperate channels is selected
							if rv["onoff_separate_channels"] then channel = rd8_inst_id end 
							local filtered_note = ARDOUR.LuaAPI.new_noteptr (channel, note:time(), note:length (), note:note (), note:velocity ())
							
							cur_command:add(filtered_note)			--add the note to the new_region
							--print(channel,filtered_note:note()) 	--debug point
						end
						cur_command:remove(note)			--discard note 
					end
			
					midi_model:apply_command(Session, midi_command)
					cur_model:apply_command(Session, cur_command)

					cur_track:playlist():add_region(new_region, region:position(), 1, false, 0, 0, false) 	--add new_region to created instrument track
				end
			end
		end
	end

	new_region = nil
	cur_inst_tracklist = nil
	filtered_note = nil
	cur_model = nil
	cur_command = nil
	midi_model = nil
	midi_command = nil

	collectgarbage()

	::script_end::
end end
