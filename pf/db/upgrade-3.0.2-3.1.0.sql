--
-- Swapping from integer to varchar on the trigger ids.
-- We can still do ranges because MySQL appropriately casts stuff.
--

ALTER TABLE `trigger`
	MODIFY `tid_start` varchar(255) NOT NULL,
	MODIFY `tid_end` varchar(255) NOT NULL
;

-- 
-- Statement of Health (SoH) related changes
--
-- The web interface allows you to create any number of named filters,
-- which are a collection of rules. A rule is a specific condition that
-- must be satisfied by the statement of health, e.g. "anti-virus is not
-- installed". The rules in a filter are ANDed together to determine if
-- the specified action is to be executed.

--
-- One entry per filter.
--

create table soh_filters (
    filter_id int not null primary key auto_increment,
    name varchar(32) not null unique,

    -- If action is null, this filter won't do anything. Otherwise this
    -- column may have any value; "accept" and "violation" are currently
    -- recognised and acted upon.
    action varchar(32),

    -- If action = 'violation', then this column contains the vid of a
    -- violation to trigger. (I wish I could write a constraint to
    -- express this.)
    vid int
) ENGINE=InnoDB;

insert into soh_filters (name) values ('Default');

--
-- One entry for each rule in a filter.
--

create table soh_filter_rules (
    rule_id int not null primary key auto_increment,

    filter_id int not null,
    foreign key (filter_id) references soh_filters (filter_id)
        on delete cascade,

    -- Any valid health class, e.g. "antivirus"
    class varchar(32) not null,

    -- Must be 'is' or 'is not'
    op varchar(16) not null,

    -- May be 'ok', 'installed', 'enabled', 'disabled', 'uptodate',
    -- 'microsoft' for now; more values may be used in future.
    status varchar(16) not null
) ENGINE=InnoDB;
