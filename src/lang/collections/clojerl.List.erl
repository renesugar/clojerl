-module('clojerl.List').

-export([
         new/1,
         to_list/1
        ]).

-type type() :: {?MODULE, list()}.


-spec new(list()) -> type().
new(Items) -> {?MODULE, Items}.

-spec to_list(type()) -> list().
to_list({_, List}) -> List.
