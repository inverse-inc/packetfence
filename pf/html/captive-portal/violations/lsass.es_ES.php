<?
/**
 * Failed scan remediation page
 *
 * Spanish version
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

$description_header = 'Los parches de Windows no estan actualizados';

$description_text = 'Debido a la amenaza que posee para otros sistemas en la red, la conectividad de la red ha sido deshabilitada hasta que se tomen acciones correctivas. Instrucciones para la desinfección estan en la parte inferior:';

$remediation_header = 'Parches de Windows no actualizados';

$remediation_text ="<ol>
  <li>Haga clic en el botón \"Habilitar Red\" a continuación.</li>
  <li>Cuando se le solicite, guarde el archivo stinger.exe en lugar adecuado en su computador (como su Escritorio o la carpeta 'Mis Documentos').</li>
  <li>Si usted esta corriendo Windows ME o Windows XP, por favor siga los pasos a continuación para deshabilitar la restauración del sistema:</li>

  <p class='sub_header'>Windows ME</p>

  <ul>
    <li> Haga clic derecho sobre el icono 'Mi PC'en su escritorio. Haga clic en 'Propriedades'.</li>
    <li>Haga clic sobre la pestaña 'Rendimiento'.</li>    <li>Haga clic en el botón 'Archivos del sistema' button.</li>
    <li>Haga clic en la pestaña 'Solución de problemas'.</li>
    <li>Marque la casilla 'Deshabilitar Restaurar Sistema'. Presione OK.</li>
    <li>Reinicie el computador.</li>
  </ul>

  <p class='sub_header'>Windows XP</p>
  <ul>
    <li>Haga clic derecho sobre el icono 'Mi PC'en su escritorio. Haga clic en 'Propriedades'.</li>
    <li>Haga clic en la pestaña 'Restaurar Sistema'.</li>
    <li>Marque la casilla 'Deshabilitar Restaurar Sistema'. Presione OK.</li>
    <li>Reinicie el computador.</li>
  </ul>
  <br/>
  <li>Ejecute el archivo stinger.exe</li>
  <li>Asegurese que todos las particiones (usualmente c:\) esten listadas bajo de 'Directories to Scan.'</li>
  <li>Haga clic en \"scan now\", y la utilidad Stinger reparará los archivos infectados.</li>
  <li>Si esta ejecutando Windows ME o Windows XP, hablite de nuevo la restauración del sistema repitiendo el paso 3.</li>
  <li>Visite Windows Update para asegurarse que su sistema esta completamente actualizado.</li>
</ol>

<p class='sub_header'>Habilitar nuevamente su Ingreso a la Red</p>
Haga clic en el botón \"Habilitar Red\", a continuación se habilitará nuevamente su acceso a la red por algunos minutos.
Durante este tiempo, usted debe seguir las instrucciones anteriormente listadas para corregir el problema. Si falla en 
hacerlo esto resultará en que el acceso a la red nuevamente sea deshabilitado. Repetidas fallas harán que el acceso sea permanentemente deshabilitado.";

?>
