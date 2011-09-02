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

$remediation_text ="<ol>
  <li>Click the \"Enable Network\" button below.</li>
  <li>When prompted, save the stinger.exe file to a convenient location on your computer (such as your Desktop).</li>
  <li>If you are running Windows ME or Windows XP, please follow these steps to disable system restore:</li>

  <p class='sub_header'>Windows ME</p>

  <ul>
    <li>Right click on the 'My Computer' icon on your desktop. Click 'Properties.'</li>
    <li>Click on the 'Performance' tab.</li>
    <li>Click on the 'File System' button.</li>
    <li>Click on the 'Troubleshooting' tab.</li>
    <li>Put a check mark next to 'Disable System Restore'. Press OK.</li>
    <li>Restart computer.</li>
  </ul>

  <p class='sub_header'>Windows XP</p>

  <ul>
    <li>Right click on the 'My Computer' icon on your desktop. Click 'Properties.'</li>
    <li>Click on the 'System Restore' tab.</li>
    <li>Put a check mark next to 'Turn off System Restore.' Press OK.</li>
    <li>Restart Computer.</li>
  </ul>
  <br> 
  <li>Run the stinger.exe file.</li>
  <li>Make sure that all of your Hard Drives (usually c:\) are listed under 'Directories to Scan.'</li>
  <li>Click \"scan now\", and the Stinger utility will repair the infected files.</li>
  <li>If you are running Windows ME or Windows XP, re-enable system restore by repeating step 3.</li>
  <li>Visit Windows Update to ensure your system is properly patched.</li>
</ol>
  
<p class='sub_header'>Re-enabling Your Network Access</p>

Clicking the \"Enable Network\" button below will re-enable your network access for minutes. During this window, you must follow the instructions listed above to correct the issue. Failure to do so will result in network access again being disabled. Repeated failures will result in access being disabled permanently.";

?>
