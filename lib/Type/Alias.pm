package Type::Alias;
use strict;
use warnings;

our $VERSION = "0.04";

use feature qw(state);
use Carp qw(croak);
use Scalar::Util qw(blessed);
use Types::Standard qw(Dict Tuple);

sub import {
    my ($class, %args) = @_;

    my $target_package = caller;

    $class->_define_type($target_package, $args{type});
    $class->_predefine_type_aliases($target_package, $args{'-alias'});
    $class->_predefine_type_functions($target_package, $args{'-fun'});
}

sub _define_type {
    my ($class, $target_package, $options) = @_;
    $options //= {};
    my $type_name = $options->{'-as'} // 'type';

    if ($target_package->can($type_name)) {
        croak "Alreay exists function '${target_package}::${type_name}'. Can specify another name: type => { -as => 'XXX' }.";
    }

    no strict qw(refs);
    no warnings qw(once);
    *{"${target_package}::${type_name}"} = sub {
        my ($alias_name, $type_args) = @_;

        no strict qw(refs);
        no warnings qw(redefine); # Already define empty type alias at _import_type_aliases
        *{"${target_package}::${alias_name}"} = generate_type_alias($type_args);
    }
}

sub _predefine_type_aliases {
    my ($class, $target_package, $type_aliases) = @_;
    $type_aliases //= [];

    for my $alias_name (@$type_aliases) {
        if ($target_package->can($alias_name)) {
            croak "Cannot predeclare type alias '${target_package}::${alias_name}'.";
        }

        no strict qw(refs);
        *{"${target_package}::${alias_name}"} = sub :prototype() {
            croak "You should define type alias '$alias_name' before using it."
        }
    }
}

sub _predefine_type_functions {
    my ($class, $target_package, $type_functions) = @_;
    $type_functions //= [];

    for my $type_function (@$type_functions) {
        if ($target_package->can($type_function)) {
            croak "Cannot predeclare type function '${target_package}::${type_function}'.";
        }

        no strict qw(refs);
        *{"${target_package}::${type_function}"} = sub :prototype(;$) {
            croak "You should define type function '$type_function' before using it."
        }
    }
}

sub to_type {
    my $v = shift;
    if (blessed($v)) {
        if ($v->can('check') && $v->can('get_message')) {
            return $v;
        }
        else {
            croak 'This object is not supported: '. ref $v;
        }
    }
    elsif (ref $v) {
        if (ref $v eq 'ARRAY') {
            return Tuple[ map { to_type($_) } @$v ];
        }
        elsif (ref $v eq 'HASH') {
            return Dict[
                map { $_ => to_type($v->{$_}) } sort { $a cmp $b } keys %$v
            ];
        }
        elsif (ref $v eq 'CODE') {
            return sub {
                my @args;
                if (@_) {
                    unless (@_ == 1 && ref $_[0] eq 'ARRAY') {
                        croak 'This type requires an array reference';
                    }
                    @args = map { to_type($_) } @{$_[0]};
                }

                to_type($v->(@args));
            }
        }
        else {
            croak 'This reference is not supported: ' . ref $v ;
        }
    }
    else {
        # TODO: Is it better to make it a type that checks whether it matches the given value?
        croak 'This value is not supported: ' . (defined $v ? $v : 'undef');
    }
}

sub generate_type_alias {
    my ($type_args) = @_;

    if ( (ref $type_args||'') eq 'CODE') {
        return sub :prototype(;$) {
            state $type = to_type($type_args);
            $type->(@_);
        };
    }
    else {
        return sub :prototype() {
            state $type = to_type($type_args);
            $type;
        }
    }
}

1;
__END__

=encoding utf-8

=head1 NAME

Type::Alias - type alias for type constraints

=head1 SYNOPSIS

    use Type::Alias -alias => [qw(ID User UserData)], -fun => [qw(List)];
    use Types::Standard -types;

    type ID => Str;

    type User => {
        id   => ID,
        name => Str,
        age  => Int,
    };

    type List => sub {
        my ($R) = @_;
        $R ? ArrayRef[$R] : ArrayRef;
    };

    type UserData => List[User] | User;

    UserData->check([
        { id => '1', name => 'foo', age => 20 },
        { id => '2', name => 'bar', age => 30 },
    ]); # OK

    UserData->check(
        { id => '1', name => 'foo', age => 20 },
    ); # OK

    # Internally List[User] is equivalent to the following type:
    #
    # ArrayRef[
    #     Dict[
    #         age=>Int,
    #         id=>Str,
    #         name=>Str
    #     ]
    # ]

=head1 DESCRIPTION

Type::Alias creates type aliases and type functions for existing type constraints such as Type::Tiny, Moose, Mouse. The aim of this module is to enhance the reusability of types and make it easier to express types.

=head2 IMPORT OPTIONS

=head3 -alias

C<-alias> is an array reference that defines type aliases. The default is C<[]>.

    use Type::Alias -alias => [qw(ID User)];

    type ID => Str;

    type User => {
        id   => ID,
        name => Str,
        age  => Int,
    };

=head3 -fun

C<-fun> is an array reference that defines type functions. The default is C<[]>.

    use Type::Alias -fun => [qw(List)];

    type List => sub($R) {
       $R ? ArrayRef[$R] : ArrayRef;
    };

=head3 type

The C<type> option is used to configure the type function that defines type aliases and type functions.

    # Rename type function:
    use Type::Alias type => { -as => 'mytype' };

    mytype ID => Str; # declare type alias

=head2 EXPORTED FUNCTIONS

=head3 type($alias_name, $type_args)

C<type> is a function that defines type alias and type function.
It recursively generates type constraints based on C<$type_args>.

Given a type constraint in C<$type_args>, it returns the type constraint as is.
Type::Alias treats objects with C<check> and C<get_message> methods as type constraints.

    type ID => Str;

    ID->check('foo'); # OK

Internally C<ID> is equivalent to the following type:

    sub ID() { Str }

Given a hash reference in C<$type_args>, it returns the type constraint defined by Type::Tiny's Dict type.

    type Point => {
        x => Int,
        y => Int,
    };

    Point->check({
        x => 1,
        y => 2
    }); # OK

Internally C<Point> is equivalent to the following type:

    sub Point() { Dict[x=>Int,y=>Int] }

Given an array reference in C<$type_args>, it returns the type constraint defined by Type::Tiny's Tuple type.

    type Option => [Str, Int];

    Option->check('foo', 1); # OK

Internally C<Option> is equivalent to the following type:

    sub Option() { Tuple[Str,Int] }

Given a code reference in C<$type_args>, it defines a type function that accepts a type constraint as an argument and return the type constraint.

    type List => sub($R) {
       $R ? ArrayRef[$R] : ArrayRef;
    };

    type Points => List[{ x => Int, y => Int }];

    Points->check([
        { x => 1, y => 2 },
        { x => 3, y => 4 },
    ]); # OK

Internally C<List> is equivalent to the following type:

    sub List :prototype(;$) {
       my @args = map { Type::Alias::to_type($_) } @{$_[0]};

        sub($R) {
           $R ? ArrayRef[$R] : ArrayRef;
        }->(@args);
    }

And C<Points> is equivalent to the following type:

    sub Points() { List[Dict[x=>Int,y=>Int]] }

=head1 COOKBOOK

=head2 Exporter

Type::Alias is designed to be used with Exporter. The following is an example of using Type::Alias with Exporter.

    package MyService {

        use Exporter 'import';
        our @EXPORT_OK = qw(hello Message);

        use Type::Alias -alias => [qw(Message)];
        use Types::Common -types;

        type Message => StrLength[1, 100];

        sub hello { ... }
    }

    package MyApp {

        use MyService qw(Message);
        Message->check('World!');
    }

=head2 Class builders

Type::Alias is designed to be used with class builders such as L<Moose>, L<Moo> and L<Mouse>.

    package Sample {
        use Moose;

        use Exporter 'import';
        our @EXPORT_OK = qw( UserName );

        use Type::Alias -alias => [qw( UserName )];
        use Types::Standard qw( Str );

        type UserName => Str & sub { length $_ > 1 };

        has 'name' => (is => 'rw', isa => UserName);
    }

    package MyApp {

        use Sample qw( UserName );

        my $sample = Sample->new(name => 'hello');
        $sample->hello; # => 'hello'
        $sample->hello(''); # ERROR!

        UserName->check('hello'); # OK
    }

=head2 Validation modules

Type::Alias is designed to be used with validation modules such as L<Type::Params>, L<Smart::Args::TypeTiny> and L<Data::Validator>:

    use Type::Alias -alias => [qw( Message )];
    use Types::Standard qw( Str );
    use Type::Params -sigs;

    type Message => Str & sub { length($_) > 1 };

    signature_for hello => (
        positional => [ Message ],
    );

    sub hello {
        my ($message) = @_;
        return "HELLO " . $message;
    }

    hello('World') # => 'HELLO World';
    hello('') # => Error!

=head3 NOTE

L<Function::Parameters> works using type aliases from outside.

    package Sample {

        use Exporter 'import';
        our @EXPORT_OK = qw(User);

        use Type::Alias -alias => [qw(User)];
        use Types::Standard -types;

        type User => {
            name => Str,
        };
    }

    use Types::Standard -types;
    use Function::Parameters;

    use Sample qw(User);

    fun hello (User $user) {
        return "Hello, $user->{name}!";
    }

    hello({ name => 'foo' }) # => 'Hello, foo!';

However, if you write a type alias inline as follows, the current implementation will not work.

    use Type::Alias -alias => [qw(Gorilla)];

    type Gorilla => Dict[ name => Str ];

    fun ooh(Gorilla $user) { # => ERROR: type Gorilla is not defined at compile time
        return "ooh ooh, $user->{name}!";
    }

    ooh({ name => 'gorilla' }) # => 'ooh ooh, gorilla!';

=head1 SEE ALSO

L<Type::Tiny>

=head1 LICENSE

Copyright (C) kobaken.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

kobaken E<lt>kfly@cpan.orgE<gt>

=cut

