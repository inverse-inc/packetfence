<?php
/**
 * display.inc: output-related functions
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
 * @copyright   2011 Inverse inc.
 * @license     http://opensource.org/licenses/gpl-2.0.php      GPLv2 or later
 */

    /*
     * print an error
     */
    function print_error($msg) {
      print "<div id='error'>$msg</div>";
    }

    function print_notice($msg) {
      print "<div id='message_box' style='margin-bottom:0px; margin-top:20px;'>$msg</div>";
    }

