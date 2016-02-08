-module(clj_utils).

-export([
         char_type/1,
         char_type/2,
         parse_number/1,
         parse_symbol/1,
         desugar_meta/1,
         binary_join/2,
         ends_with/2,
         throw_when/2,
         warn_when/2,
         group_by/2,
         trace_while/2
        ]).

-define(INT_PATTERN,
        "^([-+]?)"
        "(?:(0)|([1-9][0-9]*)|0[xX]([0-9A-Fa-f]+)|0([0-7]+)|"
        "([1-9][0-9]?)[rR]([0-9A-Za-z]+)|0[0-9]+)(N)?$").
-define(FLOAT_PATTERN, "^(([-+]?[0-9]+)(\\.[0-9]*)?([eE][-+]?[0-9]+)?)(M)?$").
-define(RATIO_PATTERN, "^([-+]?[0-9]+)/([0-9]+)$").

-type char_type() :: whitespace | number | string
                   | keyword | comment | quote
                   | deref | meta | syntax_quote
                   | unquote | list | vector
                   | map | unmatched_delim | char
                   | unmatched_delim | char
                   | arg | dispatch | symbol.

%%------------------------------------------------------------------------------
%% Exported functions
%%------------------------------------------------------------------------------

-spec parse_number(binary()) -> integer() | float() | ratio().
parse_number(Number) ->
  Result = case number_type(Number) of
             int       -> parse_int(Number);
             float     -> parse_float(Number);
             ratio     -> parse_ratio(Number);
             undefined -> undefined
           end,

  case Result of
    undefined ->
      throw(<<"Invalid number format [", Number/binary, "]">>);
    _ ->
      Result
  end.

-spec parse_symbol(binary()) ->
  {Ns :: 'clojerl.Symbol':type(), Name :: 'clojerl.Symbol':type()}.
parse_symbol(<<>>) ->
  undefined;
parse_symbol(<<"::", _/binary>>) ->
  undefined;
parse_symbol(<<"/">>) ->
  {undefined, <<"/">>};
parse_symbol(Str) ->
  case binary:last(Str) of
    $: -> undefined;
    _ ->
      case binary:split(Str, <<"/">>) of
        [_Namespace, <<>>] ->
          undefined;
        [Namespace, <<"/">>] ->
          {Namespace, <<"/">>};
        [Namespace, Name] ->
          verify_symbol_name({Namespace, Name});
        [Name] ->
          verify_symbol_name({undefined, Name})
      end
  end.

verify_symbol_name({_, Name} = Result) ->
  NotNumeric = fun(<<C, _/binary>>) -> char_type(C) =/= number end,
  NoEndColon = fun(X) -> binary:last(X) =/= $: end,
  NoSlash = fun(X) -> binary:match(X, <<"/">>) == nomatch end,
  ApplyPred = fun(Fun) -> Fun(Name) end,
  case lists:all(ApplyPred, [NotNumeric, NoEndColon, NoSlash]) of
    true -> Result;
    false -> undefined
  end.

-spec char_type(non_neg_integer()) -> char_type().
char_type(X) -> char_type(X, <<>>).

-spec char_type(non_neg_integer(), binary()) -> char_type().
char_type(X, _)
  when X == $\n; X == $\t; X == $\r; X == $ ; X == $,->
  whitespace;
char_type(X, _)
  when X >= $0, X =< $9 ->
  number;
char_type(X, <<Y, _/binary>>)
  when (X == $+ orelse X == $-),
       Y >= $0, Y =< $9 ->
  number;
char_type($", _) -> string;
char_type($:, _) -> keyword;
char_type($;, _) -> comment;
char_type($', _) -> quote;
char_type($@, _) -> deref;
char_type($^, _) -> meta;
char_type($`, _) -> syntax_quote;
char_type($~, _) -> unquote;
char_type($(, _) -> list;
char_type($[, _) -> vector;
char_type(${, _) -> map;
char_type(X, _)
  when X == $); X == $]; X == $} ->
  unmatched_delim;
char_type($\\, _) -> char;
char_type($%, _) -> arg;
char_type($#, _) -> dispatch;
char_type(_, _) -> symbol.

-spec desugar_meta('clojerl.Map':type() |
                   'clojerl.Keyword':type() |
                   'clojerl.Symbol':type() |
                   string()) -> map().
desugar_meta(Meta) ->
  case clj_core:type(Meta) of
    'clojerl.Keyword' ->
      clj_core:hash_map([Meta, true]);
    'clojerl.Map' ->
      Meta;
    Type when Type == 'clojerl.Symbol'
              orelse Type == 'clojerl.String' ->
      Tag = clj_core:keyword(<<"tag">>),
      clj_core:hash_map([Tag, Meta]);
    _ ->
      throw(<<"Metadata must be Symbol, Keyword, String or Map">>)
  end.

-spec binary_join([binary()], binary()) -> binary().
binary_join([], _) ->
  <<>>;
binary_join([S], _) when is_binary(S) ->
  S;
binary_join([H | T], Sep) ->
  B = << <<Sep/binary, X/binary>> || X <- T >>,
  <<H/binary, B/binary>>.

-spec ends_with(binary(), binary()) -> ok.
ends_with(Str, Ends) ->
  StrSize = byte_size(Str),
  EndsSize = byte_size(Ends),
  Ends == binary:part(Str, {StrSize, - EndsSize}).

-spec throw_when(boolean(), any()) -> ok | no_return().
throw_when(true, List) when is_list(List) ->
  Reason = erlang:iolist_to_binary(lists:map(fun clj_core:str/1, List)),
  throw_when(true, Reason);
throw_when(true, Reason) ->
  throw(Reason);
throw_when(false, _) ->
  ok.

-spec warn_when(boolean(), any()) -> ok | no_return().
warn_when(true, List) when is_list(List) ->
  Reason = erlang:iolist_to_binary(lists:map(fun clj_core:str/1, List)),
  warn_when(true, Reason);
warn_when(true, Reason) ->
  error_logger:warning_msg(Reason);
warn_when(false, _) ->
  ok.

-spec group_by(fun((any()) -> any()), list()) -> map().
group_by(GroupBy, List) ->
  Group = fun(Item, Acc) ->
              Key = GroupBy(Item),
              Items = maps:get(Key, Acc, []),
              Acc#{Key => [Item | Items]}
          end,
  Map = lists:foldl(Group, #{}, List),
  ReverseValue = fun(_, V) -> lists:reverse(V) end,
  maps:map(ReverseValue, Map).

-spec trace_while(string(), function()) -> ok.
trace_while(Filename, Fun) ->
  Self = self(),
  F = fun() ->
          Self ! start,
          Fun(),
          Self ! stop
      end,
  spawn(F),

  receive start -> ok
  after 1000 -> throw(<<"Fun never started">>)
  end,

  eep:start_file_tracing(Filename),

  receive stop -> ok
  after 5000 -> ok
  end,

  eep:stop_tracing(),
  eep:convert_tracing(Filename).

%%------------------------------------------------------------------------------
%% Internal helper functions
%%------------------------------------------------------------------------------

%% @doc Valid integers can be either in decimal, octal, hexadecimal or any
%%      base specified (e.g. `2R010` is binary for `2`).
-spec parse_int(binary()) -> integer() | undefined.
parse_int(IntBin) ->
  {match, [_ | Groups]} = re:run(IntBin, ?INT_PATTERN, [{capture, all, list}]),
  case int_properties(Groups) of
    {zero, _Arbitrary, _Negate} ->
      0;
    {{Base, Value}, _Arbitrary, Negate} ->
      list_to_integer(Value, Base) * Negate;
    _ ->
      undefined
  end.

-spec int_properties([string()]) -> {zero | undefined | {integer(), string()},
                                     boolean(),
                                     boolean()}.
int_properties(Groups) ->
  Props = lists:map(fun(X) -> X =/= "" end, Groups),
  Result =
    case Props of
      [_, true | _] -> zero;
      [_, _, true | _]-> {10, nth(3, Groups)};
      [_, _, _, true | _]-> {16, nth(4, Groups)};
      [_, _, _, _, true | _]-> {8, nth(5, Groups)};
      [_, _, _, _, _, _, true | _]->
        Base = list_to_integer(lists:nth(6, Groups)),
        {Base, lists:nth(7, Groups)};
      _ ->
        undefined
    end,

  Arbitrary = nth(8, Props, false),
  Negate = nth(1, Props),
  {Result, Arbitrary, case Negate of true -> -1; false -> 1 end}.

-spec parse_float(binary()) -> float().
parse_float(FloatBin) ->
  {match, [_ | Groups]} =
    re:run(FloatBin, ?FLOAT_PATTERN, [{capture, all, list}]),
  Decimal = nth(3, Groups, "") =/= "",
  case Decimal of
    true ->
      FloatStr = nth(1, Groups),
      list_to_float(FloatStr);
    false ->
      %% When there is no decimal part we add it so we can use
      %% list_to_float/1.
      FloatStr = nth(2, Groups) ++ ".0" ++ nth(4, Groups),
      list_to_float(FloatStr)
  end.

-type ratio() :: #{type => ratio,
                   denom => integer(),
                   enum => integer()}.

-spec parse_ratio(binary()) -> ratio().
parse_ratio(RatioBin) ->
  {match, [_ | Groups]} =
    re:run(RatioBin, ?RATIO_PATTERN, [{capture, all, list}]),
  Numerator = nth(1, Groups),
  Denominator = nth(2, Groups),
  {ratio,
   list_to_integer(Numerator),
   list_to_integer(Denominator)}.

number_type(Number) ->
  Regex = #{int   => ?INT_PATTERN,
            float => ?FLOAT_PATTERN,
            ratio => ?RATIO_PATTERN},
  Fun = fun(Type, RE, Acc) ->
            case re:run(Number, RE) of
              nomatch -> Acc;
              _ -> [Type | Acc]
            end
        end,
  case maps:fold(Fun, [], Regex) of
    [] -> undefined;
    [T | _] -> T
  end.

%% @doc Like lists:nth/2 but returns `undefined` if `Index` is
%%      larger than the amount of elements in `List`.
nth(Index, List) ->
  nth(Index, List, undefined).

nth(Index, List, Default) ->
  case Index =< length(List) of
    true -> lists:nth(Index, List);
    false -> Default
  end.
