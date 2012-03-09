<?
/**
 * LSASS Worm remediation page
 *
 * TODO long desc
 * 
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301,
 * USA.
 * 
 * @author      Olivier Bilodeau <obilodeau@inverse.ca>
 * @author      Dominik Gehl <dgehl@inverse.ca>
 * @copyright   2008-2011 Inverse inc.
 * @license     http://opensource.org/licenses/gpl-2.0.php      GPL
 */

$description_header = 'LSASS Worm';

$description_text = 'Your system has been found to be infected with An LSASS-based worm. Due to the threat this infection poses for other systems on the network, network connectivity has been disabled until corrective action is taken. Instructions for disinfection are below:';

$remediation_header = 'Worm Removal';

$remediation_text = "Make sure your antivirus is working. You might want to perform a full system scan. Clicking the 'Enable Network' button below will re-enable your network access. Make sure that you followed the instructions to correct the issue. Failure to do so will result in network access being disabled again. Repeated failures will result in access being disabled permanently.";

?>
