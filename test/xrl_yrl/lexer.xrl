Definitions.

D = [0-9]

Rules.

{D}+ : {token, {int, TokenLine, list_to_integer(TokenChars)}}.
[\s\t\n]+ : skip_token.

Erlang code.
