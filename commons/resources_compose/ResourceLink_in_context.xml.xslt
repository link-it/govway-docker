<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="xml" encoding="utf-8" indent="yes"/>
  <xsl:strip-space elements="*"/>
<xsl:template match="@*|node()">
    <xsl:copy>
        <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
</xsl:template>
  <xsl:template match="Context">
    <xsl:copy>
      <xsl:apply-templates select="@* | node()"/>

       <xsl:element name="ResourceLink">
<xsl:attribute name="name">org.govway.datasource</xsl:attribute>
<xsl:attribute name="global">org.govway.datasource</xsl:attribute>
<xsl:attribute name="type">javax.sql.DataSource</xsl:attribute>
       </xsl:element>

       <xsl:element name="ResourceLink">
<xsl:attribute name="name">org.govway.datasource.console</xsl:attribute>
<xsl:attribute name="global">org.govway.datasource.console</xsl:attribute>
<xsl:attribute name="type">javax.sql.DataSource</xsl:attribute>
       </xsl:element>

    </xsl:copy>
  </xsl:template>

</xsl:stylesheet>



