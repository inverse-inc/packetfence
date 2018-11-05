package pf::dal;

=head1 NAME

pf::dal - PacketFence Data Access Layer

=cut

=head1 DESCRIPTION

pf::dal provides a thin data abstraction layer for the database tables.

This module work in conjunction with the addons/dev-helpers/bin/generator-data-access-layer.pl script

Which generates all the companion modules for table in the database.

=cut

use strict;
use warnings;
use pf::db;
use pf::log;
use pf::error qw(is_error is_success);
use pf::SQL::Abstract;
use pf::config::tenant;
use pf::dal::iterator;
use pf::constants qw($TRUE $FALSE $DEFAULT_TENANT_ID);

use Class::XSAccessor {
    accessors => [qw(__from_table __old_data)],
};

=head2 new

Create a new pf::dal object

=cut

sub new {
    my ($proto, $args) = @_;
    my $class = ref($proto) || $proto;
    my $defaults = $class->_defaults;
    my %data = (%$defaults, %{$args // {}});
    return bless \%data, $class;
}

=head2 new_from_row

Create a new pf::dal object marking it that it came from the database

=cut

sub new_from_row {
    my ($proto, $args) = @_;
    my $class = ref($proto) || $proto;
    my %data = %{$args // {}};
    $data{__old_data} = {%data};
    $data{__from_table} = 1;
    return bless \%data, $class;
}

=head2 get_dbh

Get the database handle

=cut

sub get_dbh {
    get_db_handle();
}

=head2 _default

Return the default values for pf::dal object.
Should be overridden in sub class

=cut

sub _defaults {
    return {};
}


our %MYSQL_ERROR_TO_STATUS_CODES = (
    1062 => $STATUS::CONFLICT, #ER_DUP_ENTRY
    1169 => $STATUS::CONFLICT, #ER_DUP_UNIQUE
    1586 => $STATUS::CONFLICT, #ER_DUP_ENTRY_WITH_KEY_NAME
    1021 => $STATUS::INSUFFICIENT_STORAGE, #ER_DISK_FULL
    1969 => $STATUS::REQUEST_TIMEOUT, #ER_STATEMENT_TIMEOUT
);

our $ALLOWED_ERROR = 0;

=head2 db_execute

Execute the sql query with it's bind parameters

=cut

sub db_execute {
    my ($self, $sql, @bind) = @_;
    my $attempts = 3;
    my $logger = $self->logger;
    my $status = $STATUS::INTERNAL_SERVER_ERROR;
    while ($attempts) {
        my $dbh = $self->get_dbh;
        unless ($dbh) {
            $logger->error("Cannot connect to database retrying connection");
            next;
        }
        pf::log::logstacktrace(sub{"preparing statement query $sql with bind (" . join(", ", map { defined $_ ? $_ : "(undef)"} @bind) . ")"});
        my $sth = $dbh->prepare_cached($sql);
        unless ($sth && $sth->execute(@bind)) {
            my $err = $dbh->err;
            my $errstr = $dbh->errstr;
            pf::db::db_handle_error($err);
            $status = mysql_error_to_status_code($err);
            if ($err < 2000) {
                if ($err == $MYSQL_READONLY_ERROR) {
                    $logger->warn("Attempting to update a readonly database");
                } else {
                    if ($ALLOWED_ERROR == $status) {
                        $logger->trace("Ignoring error $errstr (errno: $err)");
                    } else {
                        $logger->error("Database query failed with non retryable error: $errstr (errno: $err) [$sql]{". join(", ", map { defined $_ ?  $_ : "NULL" } @bind)  . "}");
                        db_disconnect();
                    }
                }
                last;
            }
            # retry client errors
            $logger->warn("database query failed with: $errstr (errno: $err), will try again");
            next;
        }
        return $STATUS::OK, $sth;
    } continue {
        $attempts--;
    }
    return $status, undef;
}

sub mysql_error_to_status_code {
    my ($err) = @_;
    return CORE::exists $MYSQL_ERROR_TO_STATUS_CODES{$err}
      ? $MYSQL_ERROR_TO_STATUS_CODES{$err}
      : $STATUS::INTERNAL_SERVER_ERROR;
}

=head2 find

Find the pf::dal object by it's primaries keys

=cut

sub find {
    my ($proto, $ids) = @_;
    my $select_args = $proto->find_select_args($ids);
    my ($status, $sth) = $proto->do_select(%$select_args);
    return $status, undef if is_error($status);
    my $row = $sth->fetchrow_hashref;
    $sth->finish;
    unless ($row) {
        return $STATUS::NOT_FOUND, undef;
    }
    my $dal = $proto->new_from_row($row);
    return $STATUS::OK, $dal;
}

=head2 find_select_args

find_select_args

=cut

sub find_select_args {
    my ($proto, $ids, @args) = @_;
    my $where = $proto->build_primary_keys_where_clause($ids);
    my %select_args = (
        -columns => $proto->find_columns,
        -from => $proto->find_from_tables,
        -where => $where,
    );
    return \%select_args;
}

=head2 search

Search for pf::dal using SQL::Abstract::More syntax

=cut

sub search {
    my ($proto, %args) = @_;
    my $class = ref($proto) || $proto;
    if ( CORE::exists $args{-with_class}) {
        $class = delete $args{-with_class};
    }
    my $no_default_join = delete $args{-no_default_join};
    my ($status, $sth) = $proto->do_select(
        -columns => $proto->find_columns,
        -from => $no_default_join ? $proto->table : $proto->find_from_tables,
        %args
    );
    return $status, undef if is_error($status);
    return $STATUS::OK, pf::dal::iterator->new({sth => $sth, class => $class});
}

=head2 count

Get the count of the table

=cut

sub count {
    my ($proto, @args) = @_;
    my ($status, $sth) = $proto->do_select(
        -from    => $proto->table,
        @args,
        -columns => ['COUNT(*)|count'],
    );
    return $status, undef if is_error($status);
    my $row = $sth->fetchrow_hashref;
    $sth->finish;
    return $status, $row->{count};
}

=head2 save

Save the pf::dal object in the database

=cut

sub save {
    my ($self) = @_;
    my $status = $self->pre_save;
    if (is_error($status)) {
        return $status;
    }

    return $self->upsert;
}

sub create_or_update {
    my ($self) = @_;
    my $status = do {
        local $self->{__from_table} = undef;
        local $ALLOWED_ERROR = $STATUS::CONFLICT;
        $self->insert;
    };
    return $status == $STATUS::CONFLICT ? $self->update(1) : $status;
}

sub commit_or_rollback {
    my ($self, $status, $dbh) = @_;
    if (is_error($status)) {
        if(!$dbh->rollback()) {
            $self->logger->error("Error rolling back");
            my $err = $dbh->err;
            pf::db::db_handle_error($err);
            $status = mysql_error_to_status_code($err);
        }
    } else {
        if (!$dbh->commit) {
            my $err = $dbh->err;
            $self->logger->error("Error commiting");
            pf::db::db_handle_error($err);
            $status = mysql_error_to_status_code($err);
        }
    }
    return $status;
}

=head2 pre_save

pre_save

=cut

sub pre_save { $STATUS::OK }

=head2 update

Update the pf::dal object

=cut

sub update {
    my ($self, $from_table) = @_;
    return $STATUS::UNPROCESSABLE_ENTITY unless $self->__from_table || $from_table;
    my $where         = $self->primary_keys_where_clause;
    my ($status, $update_data) = $self->_update_data;
    return $status if is_error($status);
    if (keys %$update_data == 0 ) {
       return $STATUS::OK;
    }
    ($status, my $sth) = $self->do_update(
        -table => $self->table,
        -set   => $update_data,
        -where => $where,
    );
    return $status if is_error($status);

    my $rows = $sth->rows;
    $sth->finish;
    if ($rows) {
        $self->_save_old_data();
        return $STATUS::OK;
    }

    my $info = $sth->{Database}{mysql_info};
    if ($info =~ /^.*: (\d+).*: (\d+).*: (\d+)/) {
        my ($matched, $row, $warning) = ($1, $2, $3);
        if ($matched) {
            $self->_save_old_data();
            return $STATUS::OK;
        }
    }

    return $STATUS::NOT_FOUND;
}

=head2 update_items

update items

=cut

sub update_items {
    my ($proto, @args) = @_;
    my ($status, $sth) = $proto->do_update(
        -table => $proto->table,
        @args,
    );
    return $status, undef if is_error($status);
    my $rows = $sth->rows;
    $sth->finish;
    my $info = $sth->{Database}{mysql_info};
    if ($info && $info =~ /^.*: (\d+).*: (\d+).*: (\d+)/) {
        my ($matched, $row, $warning) = ($1, $2, $3);
        return $STATUS::OK, $matched;
    }

    return $STATUS::OK, $rows;
}

=head2 insert

Insert the pf::dal object

=cut

sub insert {
    my ($self) = @_;
    if ($self->__from_table) {
        my $table = $self->table;
        $self->logger->error("Trying to insert duplicate row into $table");
        return $STATUS::FORBIDDEN;
    }
    my $insert_data = $self->_insert_data;
    return $STATUS::BAD_REQUEST unless defined $insert_data;
    if (keys %$insert_data == 0 ) {
       return $STATUS::BAD_REQUEST;
    }
    my ($status, $sth) = $self->do_insert(
        -into => $self->table,
        -values   => $insert_data,
        -no_auto_tenant_id => $self->{-no_auto_tenant_id},
    );
    return $status if is_error($status);

    my $rows = $sth->rows;
    if ($rows) {
        $self->_save_old_data();
        $self->update_auto_increment_field($sth);
        $sth->finish;
        $self->after_create_hook();
        return $STATUS::CREATED;
    }
    $sth->finish;
    return $STATUS::BAD_REQUEST;
}

sub update_auto_increment_field {
    my ($self, $sth) = @_;
    my $id = $sth->{mysql_insertid};
    if ($id) {
        my $field = $self->find_auto_increment_field();
        if ($field) {
            $self->{$field} = $id;
        }
    }
}

=head2 find_auto_increment_field

=cut

sub find_auto_increment_field {
    my ($self) = @_;
    #This is needed to reset the hash iterator
    return undef unless scalar keys %{$self->get_meta};
    while( my ($k, $v) = each %{$self->get_meta}) {
       return $k if $v->{is_auto_increment};
    }
    return undef;
}

=head2 after_create_hook

Action after you create a new dal object

=cut

sub after_create_hook {
}


=head2 _save_old_data

_save_old_data

=cut

sub _save_old_data {
    my ($self) = @_;
    my %data = %$self;
    delete @data{qw(__from_table __old_data)};
    $self->__from_table(1);
    $self->__old_data(\%data);
    return ;
}

=head2 upsert

Perform an upsert of the pf::dal object

=cut

sub upsert {
    my ($self) = @_;
    my ($status, $insert_data) = $self->_insert_data;
    return $status if is_error($status);
    if (keys %$insert_data == 0 ) {
        return $STATUS::BAD_REQUEST;
    }
    ($status, my $on_conflict) = $self->_on_conflict_data;
    return $status if is_error($status);
    ($status, my $sth) = $self->do_upsert(
        -into => $self->table,
        -values   => $insert_data,
        -on_conflict => $on_conflict,
    );
    return $status if is_error($status);

    my $rows = $sth->rows;
    $self->_save_old_data();
    if ($rows == 1) {
        $status = $STATUS::CREATED;
        $self->update_auto_increment_field($sth);
        $self->after_create_hook();
    }

    return $status;
}

=head2 _on_conflict_data

Create a hash to create the hash for the on conflict data

=cut

sub _on_conflict_data {
    my ($self) = @_;
    if ($self->__from_table) {
        my ($status, $data) = $self->_update_data;
        if (is_error($status) || (keys  %$data) > 0 ) {
            return $status, $data;
        }
        # If nothing was updated make sure that we use the default
    }
    return $self->_insert_data;
}

=head2 _insert_data

Create the hash for inserting into a table

=cut

sub _insert_data {
    my ($self) = @_;
    my $fields = $self->_insertable_fields;
    my %data;
    foreach my $field (@$fields) {
        my $new_value = $self->{$field};
        if (is_error($self->validate_field($field, $new_value))) {
            my $table = $self->table;
            $self->logger->error("Skipping invalid value (" . ($new_value // "NULL") .") in when inserting field ${table}.${field}");
            next;
        }
        $data{$field} = $new_value;
    }
    return $STATUS::OK, \%data;
}

=head2 _update_data

Return the data that needs to be updated

=cut

sub _update_data {
    my ($self) = @_;
    my $updateable_fields = $self->_updateable_fields;
    my $old_data = $self->__old_data;
    my %data;
    my $logger = $self->logger;
    foreach my $field (@$updateable_fields) {
        my $new_value = $self->{$field};
        my $old_value = $old_data->{$field};
        next if (!defined $new_value && !defined $old_value);
        next if (defined $new_value && defined $old_value && $new_value eq $old_value);
        if (is_error($self->validate_field($field, $new_value))) {
            my $table = $self->table;
            $logger->error("Skipping invalid value (" . ($new_value // "NULL" ) . ") in when updating field ${table}.${field}");
            next;
        }
        $data{$field} = $new_value;
    }
    return $STATUS::OK, \%data;
}

=head2 validate_field

Validate a field value

=cut

sub validate_field {
    my ($self, $field, $value) = @_;
    my $logger = $self->logger;
    my $meta = $self->get_meta;

    if (!CORE::exists $meta->{$field}) {
        return $STATUS::UNPROCESSABLE_ENTITY
    }

    if (!$self->is_nullable($field)) {
        if (!defined $value) {
            my $table = $self->table;
            $logger->error("Trying to save a NULL value in a non nullable field ${table}.${field}");
            return $STATUS::UNPROCESSABLE_ENTITY;
        }
    }
    if ($self->is_enum($field) && defined $value) {
        unless (CORE::exists $meta->{$field} && CORE::exists $meta->{$field}{enums_values}{$value}) {
            my $table = $self->table;
            $logger->error("Trying to save a invalid value ($value) in a non nullable field ${table}.${field}");
            return $STATUS::UNPROCESSABLE_ENTITY;
        }
    }
    return $self->_validate_field($field, $value);
}

=head2 _validate_field

A hook into validate field

=cut

sub _validate_field { $STATUS::OK }

=head2 is_enum

Checks to see if a field is enum

=cut

sub is_enum {
    my ($self, $field, $value) = @_;
    my $meta = $self->get_meta;
    if (CORE::exists $meta->{$field}) {
        return $meta->{$field}{type} eq 'ENUM';
    }
    return 0;
}

=head2 is_nullable

Checks to see if a field is nullable

=cut

sub is_nullable {
    my ($self, $field) = @_;
    my $meta = $self->get_meta;
    if (CORE::exists $meta->{$field}) {
        return $meta->{$field}{is_nullable};
    }
    return 0;
}

=head2 fields

Returns the list of fields for the pf::dal object

=cut

sub fields { [] }

=head2 logger

Return the current logger for the current pf::dal object

=cut

sub logger {
    my ($proto) = @_;
    return get_logger( ref($proto) || $proto );
}
 
=head2 primary_keys_where_clause

Create the primary key where clause

=cut

sub primary_keys_where_clause {
    my ($self) = @_;
    return $self->build_primary_keys_where_clause($self->{__old_data} // $self);
}

=head2 primary_keys

Primary keys

=cut

sub primary_keys { [] }

=head2 remove_items

remove_items

=cut

sub remove_items {
    my ($proto, @args) = @_;
    my ($status, $sth) = $proto->do_delete(
        -from => $proto->table,
        @args,
    );
    return $status, undef if is_error($status);
    my $rows = $sth->rows;
    $sth->finish;
    return $status, $rows;
}

=head2 remove

Remove row from the database

=cut

sub remove {
    my ($self) = @_;
    return $STATUS::UNPROCESSABLE_ENTITY unless $self->__from_table;
    my ($status, $count) = $self->remove_items(
        -where => $self->primary_keys_where_clause
    );
    return $status if is_error($status);
    if ($count) {
        $self->__from_table(0);
        return $STATUS::OK;
    }
    return $STATUS::NOT_FOUND;
}

=head2 remove_by_id

Remove row from the database

=cut

sub remove_by_id {
    my ($self, $ids) = @_;
    my $where = $self->build_primary_keys_where_clause($ids);
    my ($status, $count) = $self->remove_items(
        -where => $where
    );
    return $status if is_error($status);
    if ($count) {
        return $STATUS::OK;
    }
    return $STATUS::NOT_FOUND;
}


=head2 exists

Checks if item exists

=cut

sub exists {
    my ($proto, $ids) = @_;
    my $where = $proto->build_primary_keys_where_clause($ids);
    my ($status, $sth) = $proto->do_select(
        -columns => [\1],
        -from    => $proto->table,
        -where   => $where,
        -limit   => 1,
    );
    if (is_error($status)) {
        return $status;
    }
    my $rows = $sth->rows;
    $sth->finish;
    if ($rows) {
        return $STATUS::OK;
    }
    return $STATUS::NOT_FOUND;
}

=head2 build_primary_keys_where_clause

=cut

sub build_primary_keys_where_clause {
    my ($self, $ids) = @_;
    my %where;
    my $table = $self->table;
    my $keys = $self->primary_keys;
    my @fullnames = map { "$table.$_"} @$keys;
    @where{@fullnames} = @{$ids}{@$keys};
    return \%where;
}

=head2 get_sql_abstract

get the sql abstract object

=cut

sub get_sql_abstract {
    return pf::SQL::Abstract->new(quote_char => '`', name_sep => '.');
}

=head2 create

Wrap new and insert

=cut

sub create {
    my ($self, @args) = @_;
    my $obj = $self->new(@args);
    return $obj->insert;
}

=head2 find_from_tables

find_from_tables

=cut

sub find_from_tables {
    my ($proto) = @_;
    return $proto->table;
}

=head2 find_or_create

finds a table record or creates it

=cut

sub find_or_create {
    my ($proto, $args) = @_;
    my $obj = $proto->new($args);
    my ($status, $sth) = $proto->do_select(
        -columns => $proto->find_columns,
        -from => $proto->find_from_tables,
        -where => $obj->primary_keys_where_clause,
    );
    if (is_success($status)) {
        my $row = $sth->fetchrow_hashref;
        $sth->finish;
        if ($row) {
            my $obj = $proto->new_from_row($row);
            return $STATUS::OK, $obj;
        }
    }
    $status =  $obj->save;
    if (is_error($status)) {
        return $status, undef;
    }
    return $status, $obj;
}

=head2 to_hash_fields

to_hash_fields

=cut

sub to_hash_fields {
    my ($self) = @_;
    return $self->field_names;
}

=head2 to_hash

Convert the object to a hash

=cut

sub to_hash {
    my ($self) = @_;
    my %hash;
    my $fields = $self->to_hash_fields;
    @hash{@$fields} = @{$self}{@$fields};
    return \%hash;
}

=head2 field_names

field_names

=cut

sub field_names {
    my ($self) = @_;
    return $self->table_field_names;
}


=head2 now

now

=cut

sub now {
    my ($proto) = @_;
    my ($status, $sth) = $proto->db_execute("SELECT NOW();");
    if (is_error($status)) {
        return undef;
    }
    my ($date) = $sth->fetchrow_array();
    $sth->finish;
    return $date;
}

=head2 merge_fields

An array ref of the fields to merge

=cut

sub merge_fields {
    my ($self) = @_;
    return $self->field_names;
}

=head2 merge

merge fields into object

=cut

sub merge {
    my ($self, $vals) = @_;
    return unless defined $vals && ref($vals) eq 'HASH';
    foreach my $field ( @{$self->merge_fields} ) {
        next unless CORE::exists $vals->{$field};
        $self->{$field} = $vals->{$field};
    }
    return ;
}

sub set_tenant {
    my ($class, $tenant_id) = @_;
    if(!defined($tenant_id)) {
        get_logger->info("Undefined tenant ID specified, ignoring it and keeping current tenant");
        return $FALSE;
    }

    my ($status, $count) = pf::dal->count(
        -where => {
            id => $tenant_id,
        },
        -from => 'tenant',
    );

    if (is_error($status)) {
        get_logger->error("Problem looking up tenant ID ($tenant_id) in database");
        return $FALSE;
    }

    if ($count == 0) {
        get_logger->error("Invalid tenant ID ($tenant_id) specified, ignoring it and keeping current tenant");
        return $FALSE;
    }

    get_logger->debug("Setting current tenant ID to $tenant_id");
    pf::config::tenant::set_tenant($tenant_id);
    return $TRUE;
}

=head2 reset_tenant

reset_tenant

=cut

sub reset_tenant {
    return pf::config::tenant::reset_tenant();
}

=head2 table

table

=cut

sub table {
    my ($self) = @_;
    return undef;
}


sub get_tenant {
    return pf::config::tenant::get_tenant();
}

=head2 select

Wrap select pf::SQL::Abstract->select

=cut

sub select {
    my ($proto, @args) = @_;
    my $sqla = $proto->get_sql_abstract;
    return $sqla->select(@args);
}

=head2 do_select

Wrap call to select and db_execute

=cut

sub do_select {
    my ($proto, @args) = @_;
    @args = $proto->update_params_for_select(@args);
    my ($sql, @bind) = $proto->select(@args);
    return $proto->db_execute($sql, @bind);
}

our %PARAMS_FOR_SELECT = (
    -columns      => 1,
    -from         => 1,
    -where        => 1,
    -union        => 1,
    -union_all    => 1,
    -intersect    => 1,
    -minus        => 1,
    -except       => 1,
    -group_by     => 1,
    -having       => 1,
    -order_by     => 1,
    -page_size    => 1,
    -page_index   => 1,
    -limit        => 1,
    -offset       => 1,
    -for          => 1,
    -want_details => 1,
);

our %PARAMS_FOR_INSERT = (
    -into      => 1,
    -values    => 1,
    -returning => 1,
);

our %PARAMS_FOR_UPDATE = (
    -table    => 1,
    -set      => 1,
    -where    => 1,
    -order_by => 1,
    -limit    => 1,
);

our %PARAMS_FOR_DELETE = (
    -from     => 1,
    -where    => 1,
    -order_by => 1,
    -limit    => 1,
);

our %PARAMS_FOR_UPSERT = (
  -into         => 1,
  -values       => 1,
  -on_conflict  => 1,
);

=head2 update_params_for_select

update_params_for_select

=cut

sub update_params_for_select {
    my ($self, %args) = @_;
    my %new_args;
    while (my ($k, $v) = each %args) {
        if (CORE::exists $PARAMS_FOR_SELECT{$k}) {
            $new_args{$k} = $v;
        }
    }
    return %new_args;
}

=head2 update_params_for_update

update_params_for_update

=cut

sub update_params_for_update {
    my ($self, %args) = @_;
    my %new_args;
    while (my ($k, $v) = each %args) {
        if (CORE::exists $PARAMS_FOR_UPDATE{$k}) {
            $new_args{$k} = $v;
        }
    }
    return %new_args;
}

=head2 update_params_for_insert

update_params_for_insert

=cut

sub update_params_for_insert {
    my ($self, %args) = @_;
    my %new_args;
    while (my ($k, $v) = each %args) {
        if (CORE::exists $PARAMS_FOR_INSERT{$k}) {
            $new_args{$k} = $v;
        }
    }
    return %new_args;
}

=head2 update_params_for_delete

update_params_for_delete

=cut

sub update_params_for_delete {
    my ($self, %args) = @_;
    my %new_args;
    while (my ($k, $v) = each %args) {
        if (CORE::exists $PARAMS_FOR_DELETE{$k}) {
            $new_args{$k} = $v;
        }
    }
    return %new_args;
}

=head2 update_params_for_upsert

update_params_for_upsert

=cut

sub update_params_for_upsert {
    my ($self, %args) = @_;
    my %new_args;
    while (my ($k, $v) = each %args) {
        if (CORE::exists $PARAMS_FOR_UPSERT{$k}) {
            $new_args{$k} = $v;
        }
    }
    return %new_args;
}

=head2 do_insert

Wrap call to pf::SQL::Abstract->insert and db_execute

=cut

sub do_insert {
    my ($proto, @args) = @_;
    my $sqla          = $proto->get_sql_abstract;
    @args = $proto->update_params_for_insert(@args);
    my ($stmt, @bind) = $sqla->insert(@args);
    return $proto->db_execute($stmt, @bind);
}

=head2 do_upsert

Wrap call to pf::SQL::Abstract->upsert and db_execute

=cut

sub do_upsert {
    my ($proto, @args) = @_;
    my $sqla          = $proto->get_sql_abstract;
    @args = $proto->update_params_for_upsert(@args);
    my ($stmt, @bind) = $sqla->upsert(@args);
    return $proto->db_execute($stmt, @bind);
}

=head2 do_update

Wrap call to pf::SQL::Abstract->update and db_execute

=cut

sub do_update {
    my ($proto, @args) = @_;
    my $sqla          = $proto->get_sql_abstract;
    @args = $proto->update_params_for_update(@args);
    my ($stmt, @bind) = $sqla->update(@args);
    return $proto->db_execute($stmt, @bind);
}

=head2 do_delete

Wrap call to pf::SQL::Abstract->delete and db_execute

=cut

sub do_delete {
    my ($proto, @args) = @_;
    my $sqla          = $proto->get_sql_abstract;
    @args = $proto->update_params_for_delete(@args);
    my ($stmt, @bind) = $sqla->delete(@args);
    return $proto->db_execute($stmt, @bind);
}

=head2 batch_remove

Batch remove rows

=cut

sub batch_remove {
    my ($proto, $search, $time_limit) = @_;
    my $logger = get_logger();
    $logger->debug("calling batch_remove with timelimit=$time_limit");
    my $start_time = time;
    my $end_time;
    my $rows_deleted = 0;
    my $table = $proto->table;
    while (1) {
        my ($status, $rows) = $proto->remove_items(%$search);
        $end_time = time;
        $rows_deleted+=$rows if $rows > 0;
        $logger->trace( sub { "deleted $rows_deleted entries from $table for batch_delete ($start_time $end_time) " });
        last if $rows <= 0 || (( $end_time - $start_time) > $time_limit );
    }
    $logger->info("deleted $rows_deleted entries from $table for batch_delete ($start_time $end_time) ");
    return $STATUS::OK, $rows_deleted;
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301,
USA.

=cut

1;
