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
    Colored = case proplists:get_value(colored, Options) of
      undefined -> false;
      C -> C
    end,
    Verb = case proplists:get_value(verbose_output, Options) of
      undefined -> false;
      V -> V
    end,
    ?reporting:new_state(Colored, Verb).

handle_begin(group, _data, State) ->
    State;
handle_begin(test, Data, State) ->
    {AtomModule, _AtomFunction, _Arity} = proplists:get_value(source, Data),
    Module = erlang:atom_to_binary(AtomModule),
    {Sub, Colored, Verb, Group, GroupStart, _} =  element(5, State),
    % Unfortunatrely handle_begin(group, ..) lacks the info we need, so
    % we need to keep the state of the last run test's group
    [NewGroup, GroupHasChanged] = case Module of
               Group -> [undefined, ok];
               _ -> [Module, changed]
           end,
    [Group2, GroupStart2] = case GroupHasChanged of
               changed ->
                 io:format('> ~w \n', [binary_to_atom(NewGroup)]),
                 [NewGroup, erlang:system_time(millisecond)];
               _ -> [Group, GroupStart]
             end,
    TestStart = erlang:system_time(millisecond),
    setelement(5, State, {Sub, Colored, Verb, Group2, GroupStart2, TestStart}).

handle_end(group, _data, State) ->
    {_Sub, _Colored, Verb, _Group, GroupStart, _TestStart} =  element(5, State),
    case Verb of
      false -> ok;
      true ->
        GroupStop = erlang:system_time(millisecond),
        Diff = GroupStop - GroupStart,
        io:format('Total: ~w ms\n', [Diff])
    end,
    State;
handle_end(test, Data, State) ->
    {AtomModule, AtomFunction, _Arity} = proplists:get_value(source, Data),
    Module = erlang:atom_to_binary(AtomModule),
    Function = erlang:atom_to_binary(AtomFunction),
    {_, _Colored, Verb, _Group, _GS, TestStart} =  element(5, State),
    case Verb of
      false -> ok;
      true ->
        TestStop = erlang:system_time(millisecond),
        Diff = TestStop - TestStart,
        % this assumes "TEST_NAME (xyz ms)" fits into 50 chars
        PadLen = byte_size(Function) + string:length(integer_to_list(Diff)) + 8,
        Pad = string:pad("", 50-PadLen, trailing),
        io:format('  ~w (~w ms)~ts', [AtomFunction, Diff, Pad])
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
