<?xml version='1.0'?> 
<xsl:stylesheet  
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"  
  xmlns:fo="http://www.w3.org/1999/XSL/Format"
  version="1.0"> 

<!-- ********************************************************************

     PacketFence Documentation Docbook FO Parameters
     Override for the Network Device Configuration Guide

     This file is part of the PacketFence project.
     Authors: 
       - Olivier Bilodeau <obilodeau@inverse.ca>

     Copyright (C) 2011 Inverse inc.
     License: GFDL 1.2 or later. http://www.gnu.org/licenses/fdl.html

     ******************************************************************** -->

  <!-- Load PacketFence's default values -->
  <xsl:import href="packetfence-fo.xsl"/>

  <!-- Table Of Contents (TOC) options -->
  <!-- In this guide we only want 2 level of ToC depth -->
  <xsl:param name="toc.section.depth" select="1"/>

</xsl:stylesheet>
<!-- vim: set shiftwidth=2 tabstop=2 expandtab: -->
