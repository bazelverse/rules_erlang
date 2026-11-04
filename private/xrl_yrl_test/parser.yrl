Nonterminals list items.
Terminals int.
Rootsymbol list.

list -> items : '$1'.
list -> '$empty' : [].
items -> int : [element(3, '$1')].
items -> int items : [element(3, '$1') | '$2'].
