-module(dir_service).
-export([start/0,dir_service/1,newset/3]).

% start the service
start() ->
    % register(dir_service, spawn(dir_service, dir_service, [{[],#{}}])),
    register(dir_service, self()),
    io:fwrite("Dir Service started~n"),
    dir_service({#{},#{},#{}}).

dir_service({ServerMap,FileMap,SizeMap}) -> 
    receive
        % add ServerMap
        {{SUAN, UAL}, add_server}->
            io:fwrite("Server ~s add request received~n",[SUAN]),
            % new dir_service
            dir_service({maps:put(SUAN,UAL,ServerMap),FileMap,SizeMap});
        % upload file
        {Client, {upload, File, Contents}} ->
            io:fwrite("Client ~p want to upload ~s~n",[Client, File]),
            [FileName|_] = string:split(File,"."),
            distribute_file({ServerMap,FileMap,SizeMap}, maps:keys(ServerMap), 0, FileName, Contents);
        % client download file
        {Client, {download, File}} ->
            io:fwrite("Client ~p want to download ~s~n",[Client, File]),
            [FileName|_] = string:split(File,"."),
            case maps:get(FileName,FileMap,"notexist") of
                % no such file
                "notexist" -> io:fwrite("File ~p not found~n",[File]),
                            Client ! "FILE NOT FOUND";
                SUANs -> sendServers(Client,ServerMap, FileName, SizeMap, sets:to_list(SUANs))
            end,
            % repeat
            dir_service({ServerMap,FileMap,SizeMap});
        % quit
        quit ->
            io:fwrite("Quiting ServerMap ~n"),
            quit(ServerMap),
            io:fwrite("All ServerMap quited ~n");
        % unkown behave
        CONFUSE -> io:fwrite("CONFUSE! ~n"),
            io:fwrite("~p~n",[CONFUSE])
    end.

% distribute file
distribute_file({ServerMap,FileMap,SizeMap}, SUANs, Index, FileName, Contents) -> 
    Len = string:len(Contents),
    case SUANs of 
        % reset server
        [] -> distribute_file({ServerMap,FileMap,SizeMap}, maps:keys(ServerMap), Index, FileName, Contents);
        % distribute files and still have contents to send
        [SUAN|REST] when (Index-1)*64<Len-> 
            % generate new file name
            Sub_FileName = FileName ++ "_" ++ integer_to_list(Index+1) ++ ".txt",
            case string:slice(Contents, Index*64, 64) of
                % end
                [] -> io:fwrite("Client uploaded ~s~n",[FileName]),
                    dir_service({ServerMap,FileMap,maps:put(FileName,Index,SizeMap)});
                NewContents->
                    {list_to_atom(SUAN),maps:get(SUAN,ServerMap)} ! {save, Sub_FileName, FileName++".txt", NewContents, Index+1},
                    % repeat 
                    distribute_file({ServerMap,maps:put(FileName,newset(FileName, SUAN, FileMap),FileMap),SizeMap}, 
                                        REST, Index+1, FileName, Contents)
            end;
        % stop
        _ -> dir_service({ServerMap,FileMap,SizeMap})
    end.
% get new filemap
newset(Key, Value, Map) -> 
    % io:fwrite("Add Value ~p to Map ~p with Key ~p~n",[Value, Map, Key]),
    sets:add_element(Value, maps:get(Key, Map, sets:new())).

% quit all ServerMap
quit(ServerMap) -> 
    Fun = fun(SUAN,UAL,_) -> {list_to_atom(SUAN),UAL} ! quit end,
    maps:fold(Fun, 0, ServerMap).

% send file servers to client
sendServers(Client,ServerMap,FileName,SizeMap, SUANs)->
    case SUANs of
        % empty
        [] -> pass,
            io:fwrite("All Servers Info sent to Client ~p with total ~p subfiles~n",[Client,maps:get(FileName,SizeMap)]);
        [SUAN|REST]->
            Client ! {server, {{SUAN,maps:get(SUAN,ServerMap)},maps:get(FileName,SizeMap)}},
            io:fwrite("Server ~p sent to Client, ~p to go~n",[SUAN,length(REST)]),
            sendServers(Client,ServerMap,FileName,SizeMap, REST)
    end.