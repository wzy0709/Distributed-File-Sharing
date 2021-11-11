-module(client).
-export([get/3, create/2]).

% download the file
get(File, ContentMap, TotalNumber) -> 
    receive
        % receive from dir service to ask file servers
        {server, {{SUAN,UAL},Total}} -> 
            % requestC(File, Servers),
            {list_to_atom(SUAN),UAL} ! {get, File, self()},
            io:fwrite("Requesting Server ~p~n",[SUAN]),
            get(File, ContentMap, Total);
        % receive from file Servers
        {contents, Contents, Index} ->
            NewMap = maps:put(Index, Contents, ContentMap),
            NewLen = maps:size(ContentMap)+1,
            io:fwrite("File contents at Index ~p got, ~p out of ~p~n",[Index,NewLen,TotalNumber]),
            if
                % received all contents
                NewLen==TotalNumber -> 
                    file:delete("downloads/"++File),
                    Fun = fun(_, C, F)->
                                file:write_file("downloads/"++F, C, [append]),
                                F
                            end,
                    maps:fold(Fun, File, NewMap),
                    io:fwrite("File create finished~n");
                % still way to go
                true -> 
                    % update contents map
                    get(File, NewMap, TotalNumber)
            end;
        % unkown behavior
        CONFUSE -> io:fwrite("CONFUSE! ~n"),
            io:fwrite("~p~n",[CONFUSE])
    end.

% upload file
create(DirUAL, File) ->
    {dir_service, (DirUAL)} ! {self(), {upload, File, util:readFile("input/"++File)}},
    io:fwrite("All contents sent to service ~n").
