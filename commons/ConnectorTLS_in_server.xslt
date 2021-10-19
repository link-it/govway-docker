<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="xml" encoding="utf-8" indent="yes"/>
  <xsl:strip-space elements="*"/>

  <xsl:template match="@*|node()">
    <xsl:copy>
        <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="Service">
    <xsl:copy>
       <xsl:apply-templates select="@* | node()"/>
       <xsl:element name="Connector">
         <xsl:attribute name="port">8443</xsl:attribute>
         <xsl:attribute name="protocol">org.apache.coyote.http11.Http11NioProtocol</xsl:attribute>
         <xsl:attribute name="SSLEnabled">true</xsl:attribute>
         <xsl:attribute name="scheme">https</xsl:attribute>
         <xsl:attribute name="secure">true</xsl:attribute>
         <xsl:attribute name="maxHttpHeaderSize=">65536</xsl:attribute>
         <xsl:element name="SSLHostConfig">
            <xsl:attribute name="truststoreFile">/var/govway/pki/stores/truststore_server.jks</xsl:attribute>
            <xsl:attribute name="truststorePassword">123456</xsl:attribute>
            <xsl:attribute name="ciphers">TLS_RSA_WITH_3DES_EDE_CBC_SHA,TLS_RSA_WITH_AES_256_CBC_SHA,TLS_RSA_WITH_AES_128_CBC_SHA,TLS_RSA_WITH_AES_256_CBC_SHA256,TLS_RSA_WITH_AES_128_CBC_SHA256,TLS_RSA_WITH_AES_256_GCM_SHA384,TLS_RSA_WITH_AES_128_GCM_SHA256,TLS_DHE_RSA_WITH_3DES_EDE_CBC_SHA,TLS_ECDHE_RSA_WITH_3DES_EDE_CBC_SHA,TLS_ECDHE_ECDSA_WITH_3DES_EDE_CBC_SHA,TLS_DHE_RSA_WITH_AES_256_CBC_SHA,TLS_DHE_RSA_WITH_AES_256_CBC_SHA256,TLS_DHE_RSA_WITH_AES_128_CBC_SHA,TLS_DHE_RSA_WITH_AES_128_CBC_SHA256,TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA,TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA,TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA384,TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA,TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384,TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA,TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256,TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256,TLS_DHE_RSA_WITH_AES_256_GCM_SHA384,TLS_DHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256</xsl:attribute>
            <xsl:attribute name="certificateVerification">optional</xsl:attribute>
            <xsl:attribute name="certificateVerificationDepth">3</xsl:attribute>
            <xsl:element name="Certificate">
              <xsl:attribute name="certificateKeystoreFile">/var/govway/pki/stores/keystore_server.jks</xsl:attribute>
              <xsl:attribute name="certificateKeystorePassword">${tls.keystorepass}</xsl:attribute>
              <xsl:attribute name="certificateKeyPassword">${tls.keypass}</xsl:attribute>
              <xsl:attribute name="certificateKeyAlias">govway_server</xsl:attribute>
              <xsl:attribute name="type">RSA</xsl:attribute>
            </xsl:element>
         </xsl:element>
       </xsl:element>
    </xsl:copy>
  </xsl:template>
</xsl:stylesheet>
