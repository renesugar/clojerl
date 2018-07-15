-module('clojerl.Set').

-include("clojerl.hrl").

-behavior('clojerl.ICounted').
-behavior('clojerl.IColl').
-behavior('clojerl.IEquiv').
-behavior('clojerl.IFn').
-behavior('clojerl.IHash').
-behavior('clojerl.IMeta').
-behavior('clojerl.ISet').
-behavior('clojerl.ISeqable').
-behavior('clojerl.IStringable').

-export([?CONSTRUCTOR/1]).
-export([count/1]).
-export([ cons/2
        , empty/1
        ]).
-export([equiv/2]).
-export([apply/2]).
-export([hash/1]).
-export([ meta/1
        , with_meta/2
        ]).
-export([ disjoin/2
        , contains/2
        , get/2
        ]).
-export([ seq/1
        , to_list/1
        ]).
-export([str/1]).

-import( clj_hash_collision
       , [ get_entry/3
         , create_entry/4
         , without_entry/3
         ]
       ).

-type mappings() :: #{integer() => {any(), true} | [{any(), true}]}.

-type type() :: #{ ?TYPE => ?M
                 , set   => map()
                 , meta  => ?NIL | any()
                 }.

-spec ?CONSTRUCTOR(list()) -> type().
?CONSTRUCTOR(Values) when is_list(Values) ->
  #{ ?TYPE => ?M
   , set   => lists:foldl(fun build_mappings/2, #{}, Values)
   , meta  => ?NIL
   };
?CONSTRUCTOR(Values) ->
  ?CONSTRUCTOR(clj_rt:to_list(Values)).

%% @private
-spec build_mappings(any(), mappings()) -> mappings().
build_mappings(Value, Map) ->
  Hash = clj_rt:hash(Value),
  Map#{Hash => create_entry(Map, Hash, Value, true)}.

%%------------------------------------------------------------------------------
%% Protocols
%%------------------------------------------------------------------------------

%% clojerl.ICounted

count(#{?TYPE := ?M, set := MapSet}) ->
  %% TODO: keep track of the count as a field
  maps:fold(fun count_fold/3, 0, MapSet).

count_fold(_, {_, _}, Count) -> Count + 1;
count_fold(_, Vs, Count)    -> Count + length(Vs).

%% clojerl.IColl

cons(#{?TYPE := ?M, set := MapSet} = Set, X) ->
  Hash  = clj_rt:hash(X),
  Entry = create_entry(MapSet, Hash, X, true),
  Set#{set => MapSet#{Hash => Entry}}.

empty(_) -> ?CONSTRUCTOR([]).

%% clojerl.IEquiv

equiv( #{?TYPE := ?M, set := X}
     , #{?TYPE := ?M, set := Y}
     ) ->
  %% TODO: this might not work when there are collisions
  'erlang.Map':equiv(X, Y);
equiv(#{?TYPE := ?M} = X, Y) ->
  clj_rt:'set?'(Y) andalso clj_rt:hash(Y) =:= hash(X).

%% clojerl.IFn

apply(#{?TYPE := ?M, set := MapSet}, [Item]) ->
  Hash = clj_rt:hash(Item),
  case get_entry(MapSet, Hash, Item) of
    ?NIL   -> ?NIL;
    {V, _} -> V
  end;
apply(_, Args) ->
  CountBin = integer_to_binary(length(Args)),
  throw(<<"Wrong number of args for set, got: ", CountBin/binary>>).

%% clojerl.IHash

hash(#{?TYPE := ?M, set := MapSet}) ->
  clj_murmur3:unordered(maps:values(MapSet)).

%% clojerl.IMeta

meta(#{?TYPE := ?M, meta := Meta}) -> Meta.

with_meta(#{?TYPE := ?M} = Set, Metadata) ->
  Set#{meta => Metadata}.

%% clojerl.ISet

disjoin(#{?TYPE := ?M, set := MapSet} = Set, Value) ->
  Hash = clj_rt:hash(Value),
  Set#{set => without_entry(MapSet, Hash, Value)}.

contains(#{?TYPE := ?M, set := MapSet}, Value) ->
  Hash = clj_rt:hash(Value),
  get_entry(MapSet, Hash, Value) /= ?NIL.

get(#{?TYPE := ?M, set := MapSet}, Value) ->
  Hash = clj_rt:hash(Value),
  case get_entry(MapSet, Hash, Value) of
    ?NIL   -> ?NIL;
    {V, _} -> V
  end.

%% clojerl.ISeqable

seq(#{?TYPE := ?M, set := MapSet} = Set) ->
  case maps:size(MapSet) of
    0 -> ?NIL;
    _ -> to_list(Set)
  end.

to_list(#{?TYPE := ?M, set := MapSet}) ->
  maps:fold(fun to_list_fold/3, [], MapSet).

to_list_fold(_Hash, {V, _}, List) ->
  [V | List];
to_list_fold(_Hash, Vs, List) ->
  [V || {V, _} <- Vs] ++ List.

%% clojerl.IStringable

str(#{?TYPE := ?M} = Set) ->
  clj_rt:print(Set).
