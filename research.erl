-module(research).

-export([init/0, close/0, start/0, loop/0, add_project/3, add_researcher/3, add_participation/2,
    add_task/6, request_add_task/7, get_project/1, get_researcher/1, request_get_project/2,
    check_percentage/1
]).

% Apro 4 tabelle DETS: tre set e una bag
init() ->
    {ok, progetti} = dets:open_file(progetti,
        [{file, "progetti.dets"}, {type, set}]),

    {ok, ricercatori} = dets:open_file(ricercatori,
        [{file, "ricercatori.dets"}, {type, set}]),

    {ok, partecipazioni} = dets:open_file(partecipazioni,
        [{file, "partecipazioni.dets"}, {type, bag}]),

    {ok, tasks} = dets:open_file(tasks,
        [{file, "tasks.dets"}, {type, set}]),

    ok.

% Funzioni dedicate all'inserimento/lettura dei dati
add_project(Id, Nome, Tipo) ->
    case dets:lookup(progetti, Id) of
        %ricerco il progetto e se non lo trovo, lo inserisco
        [] -> dets:insert(progetti, {Id, Nome, Tipo});
        % se lo trovo restituisco erroe
        [_] -> {error, project_already_exists}
    end.
get_project(Id) ->
    dets:lookup(progetti, Id).
add_researcher(Id, Nome, Ruolo) ->
    case dets:lookup(ricercatori, Id) of
        [] ->  dets:insert(ricercatori, {Id, Nome, Ruolo});
        [_] -> {error, researcher_already_exists}
    end.
get_researcher(Id) ->
    dets:lookup(ricercatori, Id).
add_participation(ProjectId, ResearcherId) ->
    %l id progetto non esiste --> ottengo project_not_found
    case dets:lookup(progetti, ProjectId) of
        [] ->
            {error, project_not_found};

        [_] ->
            %id ricercator enon esiste --> ottengo researcher_not_found
            case dets:lookup(ricercatori, ResearcherId) of
                [] ->
                    {error, researcher_not_found};

                [_] ->
                    dets:insert(partecipazioni,
                                {ProjectId, ResearcherId})
            end
    end.

% Ogni task appartiene a un progetto specifico
% Percentuale = quota di tempo del task sul totale del progetto


add_task(TaskId, ProjectId, Descrizione, ResearcherId, Stato, Percentuale) ->
    case dets:lookup(tasks, TaskId) of
        [_] ->
            {error, task_already_exists};

        [] ->
            case dets:lookup(progetti, ProjectId) of
                [] ->
                    {error, project_not_found};

                [_] ->
                    case dets:lookup(ricercatori, ResearcherId) of
                        [] ->
                            {error, researcher_not_found};

                        [_] ->
                            Partecipazioni = dets:lookup(partecipazioni, ProjectId),
                            
                            case lists:member(
                                {ProjectId, ResearcherId},
                                Partecipazioni
                            ) of
                                false ->
                                    {error, researcher_not_in_project};

                                true ->
                                    case is_number(Percentuale) andalso
                                         Percentuale >= 0 andalso
                                         Percentuale =< 100 of

                                        false ->
                                            {error, invalid_percentage};

                                        true ->
                                            {Totale, _} = check_percentage(ProjectId),

                                            case Totale + Percentuale =< 100 of
                                                true ->
                                                    dets:insert(tasks,
                                                        {TaskId, ProjectId, Descrizione,
                                                         ResearcherId, Stato, Percentuale});

                                                false ->
                                                    {error, percentage_exceeds_100}
                                            end
                                    end
                            end
                    end
            end
    end.

% Aggiungo la funzione che fa i controllo della somma delle percentuali dei task
%cerco i record che hanno un certo ProjectID, gli altri campi non mi interessano,, a parte l'ultimo che rappresenta la percentuale
check_percentage(ProjectId) ->
    Tasks = dets:select(tasks, [
        {{'_', ProjectId, '_', '_', '_', '$1'},
         [],
         ['$1']}
    ]),
    Totale = lists:sum(Tasks),
    %con la funzione lists sommo i tasks
    {Totale, Totale == 100}.
    % l'operazione restituisce true se la soma è =100 altrimenti restituisce false 

    request_get_project(ServerPid, Id) ->
    ServerPid ! {get_project, Id, self()},
    receive
        {result, Risultato} ->
            Risultato
    after 5000 ->
        timeout
    end.
%cosa succede quando nella shell si esegue; 
%ServerPid = research:start()
%viene chiamata la funzione start che ha zero parametri
%spawn crea un nuovo processo (restituisce un PID <xx.yy.zz>
%il nuovo processo richiama init che apre le tabelle DETS
%si apre il loop e il server inizia a gestire le richieste che riceve.
start() ->
    spawn(fun() ->
        init(),
        loop()
    end).

request_add_task(ServerPid, TaskId, ProjectId, Descrizione,
                 ResearcherId, Stato, Percentuale) ->
    ServerPid ! {add_task, TaskId, ProjectId, Descrizione,
                 ResearcherId, Stato, Percentuale, self()},
    receive
        {result, Risultato} ->
            Risultato
    after 5000 ->
        timeout
    end.
% Funzione del server
loop() ->
    receive

        % Inserimento progetto
        {add_project, Id, Nome, Tipo, From} ->
            Risultato = add_project(Id, Nome, Tipo),
            From ! {result, Risultato},
            loop();

        % Inserimento ricercatore
        {add_researcher, Id, Nome, Ruolo, From} ->
            Risultato = add_researcher(Id, Nome, Ruolo),
            From ! {result, Risultato},
            loop();

        % Associazione ricercatore-progetto
        {add_participation, ProjectId, ResearcherId, From} ->
            Risultato = add_participation(ProjectId, ResearcherId),
            From ! {result, Risultato},
            loop();

        % Inserimento task
        {add_task, TaskId, ProjectId, Descrizione,
            ResearcherId, Stato, Percentuale, From} ->
            Risultato = add_task(TaskId, ProjectId, Descrizione,
                                 ResearcherId, Stato, Percentuale),
            From ! {result, Risultato},
            loop();
        %ricevo una richiesta di lettura un progetto attraverso l'ID
        {get_project, Id, From} ->
            Risultato = get_project(Id),
            From ! {result, Risultato},
            loop();
                % Lettura ricercatore
        {get_researcher, Id, From} ->
            Risultato = get_researcher(Id),
            From ! {result, Risultato},
            loop();
        % Arresto del server
        stop ->
            close()
    end.
% Chiudo le tabelle DETS
close() ->
    ok = dets:close(progetti),
    ok = dets:close(ricercatori),
    ok = dets:close(partecipazioni),
    ok = dets:close(tasks),
    ok.

% Funzioni di lettura da implementare successivamente
% get_project(Id) -> dets:lookup(progetti, Id).

% get_researcher(Id) -> dets:lookup(ricercatori, Id).

% get_researchers_by_project(ProjectId) ->
%     dets:lookup(partecipazioni, ProjectId).

% get_tasks_by_project(ProjectId) ->
%     da implementare con dets:select/2.