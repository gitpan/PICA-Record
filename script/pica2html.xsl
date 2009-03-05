<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" 
                xmlns:pica="info:srw/schema/5/picaXML-v1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <!--
    pica2html.xsl

    date: 2008-02-25
    description: Display PicaXML in HTML
    author: Jakob Voss

    Changelog:
      2008-02-25: First public draft
    TODO:
      * toggle display with JavaScript
      * possibility to display blanks as (&#x2423;)
      * possibility to change subfield indicator ($)
      * possibility to mask subfield indicator in subfield values
      * mark level 1 and 2 (208@/01 etc.) and show as tree
      * add help for known semantics of fields/subfields
  -->

  <xsl:output method="html" encoding="UTF-8" indent="yes"/>

  <!-- CSS file -->
  <xsl:param name="css"/>

<xsl:param name="defaultcss">
  * { font-family: sans-serif; }

  .record {
    border: 1px solid #666666; 
    background:#c5cefa; 
    padding: 3pt;
    margin-top: 5pt;
  }
  .record-head { 
    font-weight: bold; 
  }
  .field {
    /* ... */
  }
  .error { 
    font-weight: bold;
    color:#FF0000;
   }
  .content {
    background: #e3e8fd;
  }
  .tag { 
    font-weight: bold; 
    color:#005500; 
  }
  .sfcode { 
    font-weight: bold; 
    color:#AA5500; 
  }
  a.link { text-style:italic; text-weight:default; text-decoration:underline; }
  .comment { 
    background:#FFF9EC; padding: 3px;
  }
</xsl:param>

  <!-- HTML -->
  <xsl:template match="/">
    <html>
      <head>
        <title>PicaXML in HTML</title>
        <xsl:choose>
          <xsl:when test="$css">
            <link rel="stylesheet" type="text/css" href="{$css}"/>
          </xsl:when>
          <xsl:otherwise>
            <style type="text/css">
              <xsl:value-of select="$defaultcss"/>
            </style>
          </xsl:otherwise>
        </xsl:choose>
      </head>
      <body>
        <a name="top"/>
        <h1>PicaXML in HTML</h1>
        <xsl:apply-templates select="pica:collection|pica:record"/>
      </body>
    </html>
  </xsl:template>


  <!-- Multiple records in one file -->
  <xsl:template match="pica:collection">
    <!-- TODO: show number of records -->
    <xsl:apply-templates select="pica:record"/>
  </xsl:template>


  <!-- Content of a record -->
  <xsl:template match="pica:record">
    <xsl:variable name="ppn" select="pica:datafield[@tag='003@']/pica:subfield[@code='0']"/>
    <table class="record" width="100%">
      <xsl:if test="$ppn">
        <xsl:attribute name="id">
          <xsl:text>ppn</xsl:text>
          <xsl:value-of select="$ppn"/>
        </xsl:attribute>
      </xsl:if>
      <tr>
        <td class="record-head">
          <!-- TODO: summarize some fields, for instance, for instance 003@ etc. -->
          <xsl:value-of select="count(preceding-sibling::pica:record)+1"/>
          <xsl:text>/</xsl:text>
          <xsl:value-of select="count(../pica:record)"/>
          <xsl:if test="$ppn">
            <xsl:text>(PPN </xsl:text>
            <xsl:value-of select="$ppn"/>
            <xsl:text>)</xsl:text>
          </xsl:if>
        </td>
      </tr>
      <tr>
        <td colspan="2" class="content">
          <xsl:choose>
            <xsl:when test="pica:datafield">
              <table width="100%">
                <xsl:apply-templates select="pica:datafield"/>
              </table>
            </xsl:when>  
            <xsl:otherwise>
              <p class="error">record contains no datafields!</p>
            </xsl:otherwise>
          </xsl:choose>
        </td>
      </tr>
    </table>
  </xsl:template>


  <!-- Content of a field -->
  <xsl:template match="pica:datafield">
    <xsl:variable name="tag" select="@tag"/>
    <!-- TODO: check whether a tag matches [0-9][0-9][0-9][A-Z@] -->
    <xsl:variable name="tagValid" select="true()"/>

    <tr class="field">
      <td>
        <a>
          <xsl:attribute name="class">
            <xsl:text>tag</xsl:text>
            <xsl:if test="not($tagValid)"> invalid</xsl:if>
          </xsl:attribute>
          <!--xsl:attribute name="title">
            TODO: add semantics/help with title attribute
          </xsl:attribute-->
          <xsl:value-of select="@tag"/>
          <xsl:if test="@occurrence">
            <xsl:text>/</xsl:text> <!-- TODO: how to show this? -->
            <span class="occurrence">
              <xsl:value-of select="@occurrence"/>
            </span>  
          </xsl:if>
        </a>
      </td>
      <td>
        <xsl:if test="not(pica:subfield)">
          <xsl:attribute name="class">error</xsl:attribute>
          <xsl:text>missing subfield in field!</xsl:text>
        </xsl:if>
        <xsl:apply-templates select="pica:subfield"/>
      </td>
    </tr>
  </xsl:template>

  <!-- Content of a subfield -->
  <xsl:template match="pica:subfield">
    <!-- TODO: validate @code and show semantics -->
    <a class="sfcode">
      <xsl:text>$</xsl:text>
      <xsl:value-of select="@code"/>
    </a>
    <xsl:value-of select="."/>
  </xsl:template>

</xsl:stylesheet>
