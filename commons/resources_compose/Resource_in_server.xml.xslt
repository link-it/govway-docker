<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="xml" encoding="utf-8" indent="yes"/>
  <xsl:strip-space elements="*"/>
<xsl:template match="@*|node()">
    <xsl:copy>
        <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
</xsl:template>
  <xsl:template match="GlobalNamingResources">
    <xsl:copy>
      <xsl:apply-templates select="@* | node()"/>

       <xsl:element name="Resource">
<xsl:attribute name="name">org.govway.datasource</xsl:attribute>
<xsl:attribute name="auth">Container</xsl:attribute>
<xsl:attribute name="type">javax.sql.DataSource</xsl:attribute>
<xsl:attribute name="driverClassName">org.postgresql.Driver</xsl:attribute>
<xsl:attribute name="url">jdbc:postgresql://${GOVWAY_DATABASE_SERVER}:${GOVWAY_DATABASE_PORT}/${GOVWAY_DATABASE_NAME}</xsl:attribute>
<xsl:attribute name="username">${GOVWAY_DATABASE_USERNAME}</xsl:attribute>
<xsl:attribute name="password">${GOVWAY_DATABASE_USERPASSWD}</xsl:attribute>
<xsl:attribute name="initialSize">2</xsl:attribute>
<xsl:attribute name="maxTotal">20</xsl:attribute>
<xsl:attribute name="minIdle">2</xsl:attribute>
<xsl:attribute name="maxIdle">20</xsl:attribute>
<xsl:attribute name="maxWaitMillis">30000</xsl:attribute>
<xsl:attribute name="defaultTransactionIsolation">READ_COMMITTED</xsl:attribute>
<xsl:attribute name="validationQuery">SELECT 1</xsl:attribute>
<xsl:attribute name="validationQueryTimeout">0</xsl:attribute>
<xsl:attribute name="testOnBorrow">true</xsl:attribute>
<xsl:attribute name="testOnReturn">false</xsl:attribute>
<xsl:attribute name="testWhileIdle">true</xsl:attribute>
<xsl:attribute name="minEvictableIdleTimeMillis">300000</xsl:attribute>
<xsl:attribute name="numTestsPerEvictionRun">10</xsl:attribute>
<xsl:attribute name="timeBetweenEvictionRunsMillis">60000</xsl:attribute>
<xsl:attribute name="poolPreparedStatements">true</xsl:attribute>
<xsl:attribute name="maxOpenPreparedStatements">100</xsl:attribute>
       </xsl:element>
       <xsl:element name="Resource">
<xsl:attribute name="name">org.govway.datasource.console</xsl:attribute>
<xsl:attribute name="auth">Container</xsl:attribute>
<xsl:attribute name="type">javax.sql.DataSource</xsl:attribute>
<xsl:attribute name="driverClassName">org.postgresql.Driver</xsl:attribute>
<xsl:attribute name="url">jdbc:postgresql://${GOVWAY_DATABASE_SERVER}:${GOVWAY_DATABASE_PORT}/${GOVWAY_DATABASE_NAME}</xsl:attribute>
<xsl:attribute name="username">${GOVWAY_DATABASE_USERNAME}</xsl:attribute>
<xsl:attribute name="password">${GOVWAY_DATABASE_USERPASSWD}</xsl:attribute>
<xsl:attribute name="initialSize">2</xsl:attribute>
<xsl:attribute name="maxTotal">20</xsl:attribute>
<xsl:attribute name="minIdle">2</xsl:attribute>
<xsl:attribute name="maxIdle">20</xsl:attribute>
<xsl:attribute name="maxWaitMillis">30000</xsl:attribute>
<xsl:attribute name="defaultTransactionIsolation">READ_COMMITTED</xsl:attribute>
<xsl:attribute name="validationQuery">SELECT 1</xsl:attribute>
<xsl:attribute name="validationQueryTimeout">0</xsl:attribute>
<xsl:attribute name="testOnBorrow">true</xsl:attribute>
<xsl:attribute name="testOnReturn">false</xsl:attribute>
<xsl:attribute name="testWhileIdle">true</xsl:attribute>
<xsl:attribute name="minEvictableIdleTimeMillis">300000</xsl:attribute>
<xsl:attribute name="numTestsPerEvictionRun">10</xsl:attribute>
<xsl:attribute name="timeBetweenEvictionRunsMillis">60000</xsl:attribute>
<xsl:attribute name="poolPreparedStatements">true</xsl:attribute>
<xsl:attribute name="maxOpenPreparedStatements">100</xsl:attribute>
       </xsl:element>


    </xsl:copy>
  </xsl:template>

</xsl:stylesheet>
