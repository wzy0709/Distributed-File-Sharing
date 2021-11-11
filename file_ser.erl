-module(file_ser).
-export([startS/1,file_ser/1]).

% start the server
startS(DirUAL) ->
    % get the file server name
    [Fs|_] = string:split(atom_to_list(node()),"@"),
    register(list_to_atom(Fs), self()),
    % register
    monitor_node(DirUAL, true),
    {dir_service, DirUAL} ! {{Fs, node()}, add_server},
    
    io:fwrite("File Server Started~n"),
    % start
    file_ser(#{}).

file_ser(FileMap) -> 
    % get the file server name
    [Fs|_] = string:split(atom_to_list(node()),"@"),
    receive
        % save file
        {save, SubFile, OriFile, Contents, Index}-> 
            % create directory if not exist
            file:make_dir("servers/"++Fs),
            % save file
            util:saveFile("servers/"++Fs++"/"++SubFile, Contents),
            io:fwrite("Saved file ~s~n",[SubFile]),
            file_ser(maps:put(OriFile,dir_service:newset(OriFile,{SubFile,Index},FileMap),FileMap));
        % get file
        {get, TarFile, Client} ->
            io:fwrite("Sending subfiles of ~p~n",[TarFile]),
            sendFile(Client, sets:to_list(maps:get(TarFile, FileMap)), Fs),
            file_ser(FileMap);
        %quit
        quit -> io:fwrite("File Server quited~n"),
            pass;
        % unkown behave
        CONFUSE -> io:fwrite("CONFUSE! ~n"),
            io:fwrite("~p~n",[CONFUSE])
    end.

% send all file to client
sendFile(Client, Set, Fs)->
    case Set of 
        [] -> pass;
        [{File,Index}|Rest] -> 
            io:fwrite("SubFile ~p with Index ~p sent~n",[File,Index]),
            Client ! {contents, util:readFile("servers/"++Fs++"/"++File), Index},
            sendFile(Client, Rest, Fs)
    end.
