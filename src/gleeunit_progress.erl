%% A formatter adapted from Sean Cribb's https://github.com/seancribbs/eunit_formatters

-module(gleeunit_progress).
-define(NOTEST, true).

%% eunit_listener callbacks
-export([
    init/1, handle_begin/3, handle_end/3, handle_cancel/3, terminate/2,
    start/0, start/1
]).

-define(reporting, gleeunit@internal@reporting).

start() ->
    start([]).

start(Options) ->
    eunit_listener:start(?MODULE, Options).

init(Options) ->
    Verb = case proplists:get_value(verbose_output, Options) of
      undefined -> false;
      V -> V
    end,
    ?reporting:new_state(Verb).

handle_begin(group, _data, State0) ->
    State0;
handle_begin(test, _data, State0) ->
    Start = erlang:system_time(millisecond),
    X1 = element(1,State0),
    X2 = element(2,State0),
    X3 = element(3,State0),
    X4 = element(4,State0),
    X5 = element(5,State0),
    Y1 = element(1,X5),
    Y2 = element(2,X5),
    {X1, X2, X3, X4,{Y1, Y2, Start}}.

handle_end(group, _data, State) ->
    State;
handle_end(test, Data, State) ->
    {AtomModule, AtomFunction, _Arity} = proplists:get_value(source, Data),
    Module = erlang:atom_to_binary(AtomModule),
    Function = erlang:atom_to_binary(AtomFunction),
    Sub = element(5, State),
    Verb = element(2, Sub),
    Start = element(3, Sub),
    case Verb of
      false -> ok;
      true ->
        Stop = erlang:system_time(millisecond),
        Diff = Stop - Start,
        %io:format('~w  ',[Data]),
        io:format('~w (~w ms) ',[AtomFunction,Diff])
    end,

    % EUnit swallows stdout, so print it to make debugging easier.
    case proplists:get_value(output, Data) of
        undefined -> ok;
        <<>> -> ok;
        Out -> gleam@io:print(Out)
    end,

    case proplists:get_value(status, Data) of
        ok ->
            ?reporting:test_passed(State);
        {skipped, _Reason} ->
            ?reporting:test_skipped(State, Module, Function);
        {error, {_, Exception, _Stack}} ->
            ?reporting:test_failed(State, Module, Function, Exception)
    end.


handle_cancel(_test_or_group, Data, State) ->
    ?reporting:test_failed(State, <<"gleeunit">>, <<"main">>, Data).

terminate({ok, _Data}, State) ->
    ?reporting:finished(State),
    ok;
terminate({error, Reason}, State) ->
    ?reporting:finished(State),
    io:fwrite("
Eunit failed:

~80p

This is probably a bug in gleeunit. Please report it.
", [Reason]),
    sync_end(error).

sync_end(Result) ->
    receive
        {stop, Reference, ReplyTo} ->
            ReplyTo ! {result, Reference, Result},
            ok
    end.
