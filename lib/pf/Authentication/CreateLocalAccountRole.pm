package pf::Authentication::CreateLocalAccountRole;

use Moose::Role;

has 'create_local_account' => (isa => 'Str', is => 'rw', default => 'no');
has 'local_account_logins' => (isa => 'Str', is => 'rw', default => 0);

1;
