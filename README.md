[![Actions Status](https://github.com/kfly8/Type-Alias/actions/workflows/test.yml/badge.svg)](https://github.com/kfly8/Type-Alias/actions) [![Coverage Status](https://img.shields.io/coveralls/kfly8/Type-Alias/main.svg?style=flat)](https://coveralls.io/r/kfly8/Type-Alias?branch=main) [![MetaCPAN Release](https://badge.fury.io/pl/Type-Alias.svg)](https://metacpan.org/release/Type-Alias)
# NAME

Type::Alias - type alias for type constraints

# SYNOPSIS

```perl
use Type::Alias -declare => qw(ID User List Hoge);
use Types::Standard -types;

type ID => Str;

type User => {
    id   => ID,
    name => Str,
    age  => Int,
};

type List => sub($R) {
    [$R]
};

type Hoge => List[User] | User;

Hoge;
# =>
# ArrayRef[
#     Dict[
#         age=>Int,
#         id=>Str,
#         name=>Str
#     ]
# ]
# |
# Dict[
#     age=>Int,
#     id=>Str,
#     name=>Str
# ]

our @EXPORT_OK; # => ID User List Hoge
```

# DESCRIPTION

Type::Alias is ...

# LICENSE

Copyright (C) kobaken.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

kobaken <kentafly88@gmail.com>
