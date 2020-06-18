package maint

import (
	"time"
)

type AcctCleanup struct {
	Task
	Window               int
	Batch                int
	Timeout              time.Duration
	RadAcctDeleteStmt    StmtSetup
	RadAcctLogDeleteStmt StmtSetup
	RadAcctUpdateStmt    StmtSetup
}

func NewAcctCleanup(config map[string]interface{}) JobSetupConfig {
	return &AcctCleanup{
		Task: Task{
			Type:         config["type"].(string),
			Status:       config["status"].(string),
			Description:  config["description"].(string),
			ScheduleSpec: config["schedule"].(string),
		},
		Batch:   int(config["batch"].(float64)),
		Timeout: time.Duration((config["timeout"].(float64))) * time.Second,
		Window:  int(config["window"].(float64)),
	}
}

const radAcctUpdateStmtSQL = `
UPDATE radacct SET acctstoptime = NOW() 
    WHERE acctstarttime < DATE_SUB(?, INTERVAL ? SECOND) AND 
          acctstoptime IS NULL
    LIMIT ?
`

const radAcctDeleteStmtSQL = `
DELETE FROM radacct 
    WHERE acctstarttime < DATE_SUB(?, INTERVAL ? SECOND) AND 
          acctstoptime IS NOT NULL
    LIMIT ?
`

const radAcctLogDeleteSQL = `
DELETE FROM radacct_log
    WHERE timestamp DATE_SUB(?, INTERVAL ? SECOND)
    LIMIT ?
`

func (c *AcctCleanup) Run() {
	if c.Window == 0 {
		return
	}

	now := time.Now()

	if radAcctUpdateStmt := c.RadAcctUpdateStmt.Stmt(radAcctUpdateStmtSQL); radAcctUpdateStmt != nil {
		BatchStmt(radAcctUpdateStmt, c.Timeout, now, c.Window, c.Batch)
	}

	if radAcctDeleteStmt := c.RadAcctDeleteStmt.Stmt(radAcctDeleteStmtSQL); radAcctDeleteStmt != nil {
		BatchStmt(radAcctDeleteStmt, c.Timeout, now, c.Window, c.Batch)
	}

	if radAcctLogDeleteStmt := c.RadAcctLogDeleteStmt.Stmt(radAcctLogDeleteSQL); radAcctLogDeleteStmt != nil {
		BatchStmt(radAcctLogDeleteStmt, c.Timeout, now, c.Window, c.Batch)
	}
}

/*
sub cleanup {
    my $timer = pf::StatsD::Timer->new( { sample_rate => 0.2 } );
    my ( $expire_seconds, $batch, $time_limit ) = @_;
    my $logger = get_logger();
    $logger->debug( sub { "calling accounting_cleanup with time=$expire_seconds batch=$batch timelimit=$time_limit"; });

    if ( $expire_seconds eq "0" ) {
        $logger->debug("Not deleting because the window is 0");
        return;
    }
    my $now        = pf::dal->now();

    # Close old un-updated sessions
    my %params = (
        -set => {
            acctstoptime => \"NOW()",
        },
        -where => {
            acctupdatetime => {
                "<" => \[ 'DATE_SUB(?, INTERVAL ? SECOND)', $now, $expire_seconds ]
            },
            acctstoptime => undef,
        },
        -limit => $batch,
        -no_auto_tenant_id => 1,
    );
    pf::dal::radacct->batch_update(\%params, $time_limit);

    # Cleanup the radacct table
    %params = (
        -where => {
            acctstarttime => {
                "<" => \[ 'DATE_SUB(?, INTERVAL ? SECOND)', $now, $expire_seconds ]
            },
            acctstoptime => { "!=", undef },
        },
        -limit => $batch,
        -no_auto_tenant_id => 1,
    );
    pf::dal::radacct->batch_remove(\%params, $time_limit);

    # Cleanup the radacct_log table
    %params = (
        -where => {
            timestamp => {
                "<" => \[ 'DATE_SUB(?, INTERVAL ? SECOND)', $now, $expire_seconds ]
            },
        },
        -limit => $batch,
        -no_auto_tenant_id => 1,
    );
    pf::dal::radacct_log->batch_remove(\%params, $time_limit);
    return;
}
*/
