<?php
/**
 * forms.inc: forms-related functions
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
     * wraps given content around a form. form fields will be hidden key => value added in the form 
     * Some actions are just better behind a POST
     *
     * TODO we would need to port a lot of the code to use this
     */
    function formify($form_action, $form_fields, $content) {
        print "<form action='$form_action' method='POST'>\n";
        foreach ($form_fields as $name => $value) {
            print "  <input type='hidden' name='$name' value='$value'>\n";
        }
        print "$content";
        print "</form>";
    }

    /*
     * image-based delete button with required confirmation
     *
     * TODO we would need to port a lot of the code to use this
     */
    function delete_button($form_action, $form_fields, $dialog) {
        formify(
            $form_action, $form_fields, 
            "<input class=\"button\" type='image' src='/images/famfamfam_silk_icons/page_delete.png' align=bottom title='Delete this record' onClick=\"return confirm('$dialog');\">"
        );
    }

    /*
     * image-based button
     *
     */
    function image_button($form_action, $form_fields, $image, $alt_text) {
        formify(
            $form_action, $form_fields, 
            "<input class=\"button\" type='image' src='$image' align=bottom title='$alt_text' />"
        );
    }

