--
-- Source: StatusNet
-- 

--
-- Schema fetched on 2010-10-15 from:
-- http://gitorious.org/statusnet/mainline/blobs/raw/master/db/statusnet.sql
--
create table sms_carrier (
    id integer primary key comment 'primary key for SMS carrier',
    name varchar(64) unique key comment 'name of the carrier',
    email_pattern varchar(255) not null comment 'sprintf pattern for making an email address from a phone number',
    created datetime not null comment 'date this record was created',
    modified timestamp comment 'date this record was modified'
) ENGINE=InnoDB CHARACTER SET utf8 COLLATE utf8_bin;

--
-- Data fetched on 2010-10-15 from:
-- http://gitorious.org/statusnet/mainline/blobs/raw/master/db/sms_carrier.sql
--
INSERT INTO sms_carrier
    (id, name, email_pattern, created)
VALUES
    (100056, '3 River Wireless', '%s@sms.3rivers.net', now()),
    (100057, '7-11 Speakout', '%s@cingularme.com', now()),
    (100058, 'Airtel (Karnataka, India)', '%s@airtelkk.com', now()),
    (100059, 'Alaska Communications Systems', '%s@msg.acsalaska.com', now()),
    (100060, 'Alltel Wireless', '%s@message.alltel.com', now()),
    (100061, 'AT&T Wireless', '%s@txt.att.net', now()),
    (100062, 'Bell Mobility (Canada)', '%s@txt.bell.ca', now()),
    (100063, 'Boost Mobile', '%s@myboostmobile.com', now()),
    (100064, 'Cellular One (Dobson)', '%s@mobile.celloneusa.com', now()),
    (100065, 'Cingular (Postpaid)', '%s@cingularme.com', now()),
    (100066, 'Centennial Wireless', '%s@cwemail.com', now()),
    (100067, 'Cingular (GoPhone prepaid)', '%s@cingularme.com', now()),
    (100068, 'Claro (Nicaragua)', '%s@ideasclaro-ca.com', now()),
    (100069, 'Comcel', '%s@comcel.com.co', now()),
    (100070, 'Cricket', '%s@sms.mycricket.com', now()),
    (100071, 'CTI', '%s@sms.ctimovil.com.ar', now()),
    (100072, 'Emtel (Mauritius)', '%s@emtelworld.net', now()),
    (100073, 'Fido (Canada)', '%s@fido.ca', now()),
    (100074, 'General Communications Inc.', '%s@msg.gci.net', now()),
    (100075, 'Globalstar', '%s@msg.globalstarusa.com', now()),
    (100076, 'Helio', '%s@myhelio.com', now()),
    (100077, 'Illinois Valley Cellular', '%s@ivctext.com', now()),
    (100078, 'i wireless', '%s.iws@iwspcs.net', now()),
    (100079, 'Meteor (Ireland)', '%s@sms.mymeteor.ie', now()),
    (100080, 'Mero Mobile (Nepal)', '%s@sms.spicenepal.com', now()),
    (100081, 'MetroPCS', '%s@mymetropcs.com', now()),
    (100082, 'Movicom', '%s@movimensaje.com.ar', now()),
    (100083, 'Mobitel (Sri Lanka)', '%s@sms.mobitel.lk', now()),
    (100084, 'Movistar (Colombia)', '%s@movistar.com.co', now()),
    (100085, 'MTN (South Africa)', '%s@sms.co.za', now()),
    (100086, 'MTS (Canada)', '%s@text.mtsmobility.com', now()),
    (100087, 'Nextel (Argentina)', '%s@nextel.net.ar', now()),
    (100088, 'Orange (Poland)', '%s@orange.pl', now()),
    (100089, 'Personal (Argentina)', '%s@personal-net.com.ar', now()),
    (100090, 'Plus GSM (Poland)', '%s@text.plusgsm.pl', now()),
    (100091, 'President\'s Choice (Canada)', '%s@txt.bell.ca', now()),
    (100092, 'Qwest', '%s@qwestmp.com', now()),
    (100093, 'Rogers (Canada)', '%s@pcs.rogers.com', now()),
    (100094, 'Sasktel (Canada)', '%s@sms.sasktel.com', now()),
    (100095, 'Setar Mobile email (Aruba)', '%s@mas.aw', now()),
    (100096, 'Solo Mobile', '%s@txt.bell.ca', now()),
    (100097, 'Sprint (PCS)', '%s@messaging.sprintpcs.com', now()),
    (100098, 'Sprint (Nextel)', '%s@page.nextel.com', now()),
    (100099, 'Suncom', '%s@tms.suncom.com', now()),
    (100100, 'T-Mobile', '%s@tmomail.net', now()),
    (100101, 'T-Mobile (Austria)', '%s@sms.t-mobile.at', now()),
    (100102, 'Telus Mobility (Canada)', '%s@msg.telus.com', now()),
    (100103, 'Thumb Cellular', '%s@sms.thumbcellular.com', now()),
    (100104, 'Tigo (Formerly Ola)', '%s@sms.tigo.com.co', now()),
    (100105, 'Unicel', '%s@utext.com', now()),
    (100106, 'US Cellular', '%s@email.uscc.net', now()),
    (100107, 'Verizon', '%s@vtext.com', now()),
    (100108, 'Virgin Mobile (Canada)', '%s@vmobile.ca', now()),
    (100109, 'Virgin Mobile (USA)', '%s@vmobl.com', now()),
    (100110, 'YCC', '%s@sms.ycc.ru', now()),
    (100111, 'Orange (UK)', '%s@orange.net', now()),
    (100112, 'Cincinnati Bell Wireless', '%s@gocbw.com', now()),
    (100113, 'T-Mobile Germany', '%s@t-mobile-sms.de', now()),
    (100114, 'Vodafone Germany', '%s@vodafone-sms.de', now()),
    (100115, 'E-Plus', '%s@smsmail.eplus.de', now()),
    (100116, 'Cellular South', '%s@csouth1.com', now()),
    (100117, 'ChinaMobile (139)', '%s@139.com', now());
