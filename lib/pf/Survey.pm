package pf::Survey;

use constant SURVEY => 'Survey';

use Moose;
use pf::db;
use pf::log;
use Tie::IxHash;
use pf::constants qw($TRUE $FALSE);

has 'id', (is => 'rw', isa => 'Str');

has 'description', (is => 'rw', isa => 'Str');

has 'fields', (is => 'rw', isa => 'HashRef');

# empty since no queries are prepared upfront
sub Survey_db_prepare {}

our $TABLE_PREFIX = "survey_";

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

sub table_name {
    my ($self) = @_;
    return $TABLE_PREFIX . $self->id;
}

sub create_table {
    my ($self) = @_;
    my $table_name = $self->table_name;
    my @result = pf::Survey->_db_data(SURVEY, {'table_create_sql' => "CREATE TABLE $table_name(id int(11) PRIMARY KEY AUTO_INCREMENT)"}, 'table_create_sql');

    return (@result && $result[0] == $FALSE) ? $FALSE : $TRUE;
}

sub insert_or_update_field {
    my ($self, $field_id, $config_field, $db_field) = @_;
    my $logger = get_logger();
    my $table_name = $self->table_name;

    my $wants_type = $FIELD_MAP{$config_field->{type}}{type};
    
    unless(defined($wants_type)) {
        die "Unknown field type $config_field->{type} \n";
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

        my $db_fields = { map { $_->{Field} => $_ } @desc }; 

        while(my ($field_id, $field_config) = each(%{$survey->fields})) {
            if(exists($FORBIDDEN_FIELDS{$field_id})) {
                $logger->warn("Will not create/update field $field_id as it is part of the internal fields of the surveys");
                next;
            }

            unless($survey->insert_or_update_field($field_id, $field_config, $db_fields->{$field_id})) {
                $logger->error("Failed to create/update field $field_id in table $table_name");
            }
        }
    }
}

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
