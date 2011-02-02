<?xml version='1.0'?> 
<xsl:stylesheet  
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"  
  xmlns:fo="http://www.w3.org/1999/XSL/Format"
  version="1.0"> 

  <xsl:import href="/opt/local/share/xsl/docbook-xsl/fo/docbook.xsl"/> 

  <!-- title page extra styling -->
  <xsl:import href="titlepage-fo.xsl"/>

  <!-- revision table layout -->
  <xsl:attribute-set name="revhistory.title.properties">
    <xsl:attribute name="font-size">12pt</xsl:attribute>
    <xsl:attribute name="font-weight">bold</xsl:attribute>
    <xsl:attribute name="text-align">center</xsl:attribute>
  </xsl:attribute-set>
  <xsl:attribute-set name="revhistory.table.cell.properties">
    <xsl:attribute name="border">solid</xsl:attribute>
  </xsl:attribute-set>

  <!-- grey boxes around code (screen, programlisting) -->
  <xsl:param name="shade.verbatim" select="1"/>
  <xsl:attribute-set name="shade.verbatim.style">
    <xsl:attribute name="background-color">#E0E0E0</xsl:attribute>
    <xsl:attribute name="border">solid</xsl:attribute>
  </xsl:attribute-set>

  <!-- breaking long lines in code (screen, programlisting) -->
  <xsl:attribute-set name="monospace.verbatim.properties">
    <xsl:attribute name="wrap-option">wrap</xsl:attribute>
  </xsl:attribute-set>

  <!-- don't show raw links in [ .. ] after a link -->
  <xsl:param name="ulink.show" select="0"/>

  <!-- blue underlined hyperlink -->
  <xsl:attribute-set name="xref.properties">
    <xsl:attribute name="color">blue</xsl:attribute>
    <xsl:attribute name="text-decoration">underline</xsl:attribute>
  </xsl:attribute-set>

</xsl:stylesheet>
