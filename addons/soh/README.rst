===========================
SoH support for PacketFence
===========================

Introduction
============

This addon is used to parse and act upon statement-of-health ("SoH")
indications encapsulated in 802.1x authentication exchanges. These can
be used, for example, to deny network access to clients who do not have
an anti-virus program installed, or do not have the latest updates.

For more details about Microsoft NAP (the protocol used to transmit SoH
indications), see http://technet.microsoft.com/en-us/network/bb545879

Installation and configuration
==============================

#. Enable SoH support inside the peap {} section in eap.conf:

   soh = yes
   soh-virtual-server = "soh-server"

#. Put the proper credentials in the packetfence-soh.pm file,
   and restart RADIUS.

Configuration of SoH filters
============================

Let's walk through an example situation. Suppose you want to display a
remediation page to clients that do not have an anti-virus enabled.

The three broad steps are: create a violation class for the condition,
then create an SoH filter to trigger the violation when "anti-virus is
disabled", and finally, restart PacketFence.

1. Create a violation through the admin interface, or edit
   conf/violations.conf and add a section like this:

   [4000001]
   desc=No anti-virus enabled
   url=/remediation.php?template=noantivirus
   actions=trap,email,log
   enabled=Y

   You may want to set other attributes too, like auto_enable (Y or N),
   grace, etc. Of course, you must supply an appropriate URL to display
   the remediation message.

#. Visit https://localhost:1443/soh and (edit the filter named
   "Default", or) use the "Add a filter" button to create a filter named
   "antivirus".

#. Click on "antivirus" in the filter list, and select "Trigger
   violation" in the action dropdown. Enter the vid of the violation you
   created above in the input box that appears.

   If the vid you enter does not correspond to a violation that has been
   created already, then a new violation will be created with that id,
   but you should make sure to edit its configuration appropriately.

#. Next, click on "Add a condition", and select "Anti-virus", "is", and
   "disabled" in the drop-down boxes that appear.

#. Click on the "Save filters" button.

#. Restart PacketFence.
