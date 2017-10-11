package pf::Survey;

use constant SURVEY => 'Survey';

use Moose;
use SQL::Abstract::More;
use pf::db;
use pf::log;
use Tie::IxHash;
use pf::constants qw($TRUE $FALSE);

has 'id', (is => 'rw', isa => 'Str');

has 'table', (is => 'rw', isa => 'Str');

has 'description', (is => 'rw', isa => 'Str');

has 'fields_order' => (is => 'rw', isa => 'ArrayRef', default => sub { [] });
has 'fields', (is => 'rw', isa => 'HashRef', default => sub { {} });

has 'data_fields', (is => 'rw', isa => 'HashRef', default => sub { {} });

# empty since no queries are prepared upfront
sub Survey_db_prepare {}

# The prefix of the survey tables
our $TABLE_PREFIX = "survey_";

# Fields definition for supported field types
our %FIELD_MAP = (
    "Select" => {
        type => "varchar(255)",
    },
    "Text" => {
        type => "varchar(255)",
    },
    "TextArea" => {
        type => "text",
    },
    "Scale" => {
        type => "int(1)",
    },
);

# Fields that are forbidden in surveys as they are used internally
our %FORBIDDEN_FIELDS = (
    id => 1,
);

=head2 table_name

The table name for a survey object

=cut

sub table_name {
    my ($self) = @_;
    return $TABLE_PREFIX . (defined($self->table) ? $self->table : $self->id);
}

=head2 create_table

Create the base structure of a survey table (without its fields)

=cut

sub create_table {
    my ($self) = @_;
    my $table_name = $self->table_name;
    my @result = pf::Survey->_db_data(SURVEY, {'table_create_sql' => "CREATE TABLE $table_name(id int(11) PRIMARY KEY AUTO_INCREMENT)"}, 'table_create_sql');

    return (@result && $result[0] == $FALSE) ? $FALSE : $TRUE;
}

=head2 create_or_update_field

Create or update a survey field in the database

Will make sure
- The field exists
- The field has the proper type based on FIELD_MAP

If a field has an unknown type, it will make it a varchar(255)

=cut

sub create_or_update_field {
    my ($self, $field_id, $config_field, $db_field) = @_;
    my $logger = get_logger();
    my $table_name = $self->table_name;

    my $wants_type = defined($config_field->{type}) ? $FIELD_MAP{$config_field->{type}}{type} : undef;
    
    unless(defined($wants_type)) {
        $wants_type = "varchar(255)";
    }

    if(defined($db_field)) {
        $logger->debug("Field $field_id already exists in $table_name");
        my $schema_type = $db_field->{Type};
        if($wants_type eq $schema_type) {
            $logger->debug("Field $field_id has the right type in $table_name. Leaving untouched");
            return $TRUE;
        }
        else {
            $logger->info("Modifying the type of field $field_id in $table_name from $schema_type to $wants_type");
            my @result = pf::Survey->_db_data(SURVEY, {'field_alter_sql' => "ALTER TABLE $table_name MODIFY $field_id $wants_type"}, 'field_alter_sql');
            return (@result && $result[0] == $FALSE) ? $FALSE : $TRUE;
        }
    }
    else {
        $logger->info("Field $field_id doesn't exist in $table_name, creating it");
        my @result = pf::Survey->_db_data(SURVEY, {'field_create_sql' => "ALTER TABLE $table_name ADD $field_id $wants_type"}, 'field_create_sql');
        return (@result && $result[0] == $FALSE) ? $FALSE : $TRUE;
    }
}

=head2 reload_from_config

Reload the survey tables schema based on the configuration

Will make sure:
- All the survey tables exist
- All the survey tables have the right fields
- All the survey tables fields have the right type

=cut

sub reload_from_config {
    my ($config) = @_;

    my $logger = get_logger();
    unless(db_ping()){
        $logger->error("Can't connect to db to reload the survey tables");
        return;
    }

    if (db_readonly_mode()) {
        my $msg = "Cannot reload the survey tables when the database is in read only mode\n";
        print STDERR $msg;
        $logger->error($msg);
        return;
    }

    while(my ($survey_id, $survey_config) = each(%$config)) {
        require pf::factory::survey;
        my $survey = pf::factory::survey->new($survey_id);
        my $table_name = $survey->table_name;
        my @desc = pf::Survey->_db_data(SURVEY, {'table_desc_sql' => "DESC $table_name"}, 'table_desc_sql');

        if($desc[0] == $FALSE) {
            $logger->info("Creating table $table_name");
            if($survey->create_table()) {
                $logger->info("Created table $table_name");
            }
            else {
                $logger->error("Failed to create table $table_name, survey $survey_id will not work properly");
                next;
            }
        }
        
        @desc = pf::Survey->_db_data(SURVEY, {'table_desc_sql' => "DESC $table_name"}, 'table_desc_sql');
        if($desc[0] == $FALSE) {
            $logger->error("Unable to get table description even after creating it. Bailing out.");
            return $FALSE;
        }

        my $db_fields = { map { $_->{Field} => $_ } @desc }; 

        my %merge = ( %{$survey->fields}, %{$survey->data_fields} );
        while(my ($field_id, $field_config) = each(%merge)) {
            if(exists($FORBIDDEN_FIELDS{$field_id})) {
                $logger->warn("Will not create/update field $field_id as it is part of the internal fields of the surveys");
                next;
            }

            unless($survey->create_or_update_field($field_id, $field_config, $db_fields->{$field_id})) {
                $logger->error("Failed to create/update field $field_id in table $table_name");
            }
        }
    }
}

=head2 insert_or_update_response

Inserts or updates a survey response using a hashref and an optional response ID (id column of the survey table)

$args is the contextual data around the node and connection for population of the data_fields.

=cut

sub insert_or_update_response {
    my ($self, $response, $args, $response_id) = @_;
    get_logger->debug("Attempting to insert or update survey response");

    for my $field (keys(%$response)) {
        unless(exists($self->fields->{$field})) {
            get_logger->warn("Ignoring survey field '$field' since its not part of this survey configuration");
            delete $response->{$field};
        }
    }

    if(defined($args)) {
        get_logger->debug("Contextual arguments have been supplied, populating data fields from it");

        while(my ($field, $config) = each(%{$self->data_fields})) {
            next unless(defined($config->{query}));

            my @query = split(/\./, $config->{query});
            my $result = $args;

            # dig into the hash structure to get the query attribute
            for my $query_part (@query) {
                $result = $result->{$query_part};
            }
            
            get_logger->debug("Setting survey data '$result' to field '$field'");

            $response->{$field} = $result;
        }
    }

    use Data::Dumper ; print Dumper($response);
    
    my $sqla = SQL::Abstract::More->new();

    if(defined($response_id)) {
        get_logger->info("Updating existing survey response $response_id");
        my ($sql, @params) = $sqla->update(
            -table => $self->table_name,
            -set => $response,
            -where => {id => {"=" => $response_id}},
        );
        my @result = $self->_db_data(SURVEY, {'survey_update_sql' => $sql}, 'survey_update_sql', @params);
        return (@result && $result[0] == $FALSE) ? $FALSE : $TRUE;
    }
    else {
        get_logger->info("Creating new survey response");
        my ($sql, @params) = $sqla->insert(
            -into => $self->table_name,
            -values => $response,
        );
        my @result = $self->_db_data(SURVEY, {'survey_insert_sql' => $sql}, 'survey_insert_sql', @params);
        return (@result && $result[0] == $FALSE) ? $FALSE : $TRUE;
    }
}

=head2 _db_data

Execute a query through pf::db

=cut

sub _db_data {
    my ($class, $from_module, $module_statements_ref, $query, @params) = @_;

    my $sth = db_query_execute($from_module, $module_statements_ref, $query, @params) || return ($FALSE);

    my ( $ref, @array );
    while ( $ref = $sth->fetchrow_hashref() ) {
        push( @array, $ref );
    }
    $sth->finish();
    return (@array);
}

1;
