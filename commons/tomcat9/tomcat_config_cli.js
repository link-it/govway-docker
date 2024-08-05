// Importare le classi Java necessarie
var System = Java.type('java.lang.System');
var File = Java.type('java.io.File');
var FileReader = Java.type('java.io.FileReader');
var BufferedReader = Java.type('java.io.BufferedReader');
var FileWriter = Java.type('java.io.FileWriter');
var DocumentBuilderFactory = Java.type('javax.xml.parsers.DocumentBuilderFactory');
var TransformerFactory = Java.type('javax.xml.transform.TransformerFactory');
var DOMSource = Java.type('javax.xml.transform.dom.DOMSource');
var StreamResult = Java.type('javax.xml.transform.stream.StreamResult');
var XPathFactory = Java.type('javax.xml.xpath.XPathFactory');
var XPathConstants = Java.type('javax.xml.xpath.XPathConstants');

// Funzione principale
function modifyTomcatConfig(inputFilePath) {

    // Ottenere il percorso di CATALINA_HOME
    var catalinaHome = System.getenv('CATALINA_HOME');
    if (!catalinaHome) {
        print('Errore: La variabile d\'ambiente CATALINA_HOME non è impostata.');
        return;
    }

    // Costruire il percorso al file server.xml
    var serverXmlPath = catalinaHome + File.separator + 'conf' + File.separator + 'server.xml';
    var contextXmlPath = catalinaHome + File.separator + 'conf' + File.separator + 'context.xml';

    // Carica il documento XML
    var document_server_xml = loadXMLDocument(serverXmlPath);
    var document_context_xml = loadXMLDocument(contextXmlPath);

    // Leggi le direttive dal file di input e applicale
    var bufferedReader = new BufferedReader(new FileReader(inputFilePath));
    var line;
    while ((line = bufferedReader.readLine()) != null) {
        line = line.trim();
        if (line === '' || line.startsWith('#')) {
            continue;
        }
        processDirective(document_server_xml, document_context_xml, line);
    }
    bufferedReader.close();

    // Salva il documento modificato
    saveXMLDocument(document_server_xml, serverXmlPath);
    saveXMLDocument(document_context_xml, contextXmlPath);

    print('Configurazione modificata con successo.');
}

// Carica il documento XML
function loadXMLDocument(filePath) {
    var factory = DocumentBuilderFactory.newInstance();
    var builder = factory.newDocumentBuilder();
    return builder.parse(new File(filePath));
}

// Salva il documento XML
function saveXMLDocument(document, filePath) {
    var transformerFactory = TransformerFactory.newInstance();
    var transformer = transformerFactory.newTransformer();
    var source = new DOMSource(document);
    var result = new StreamResult(new File(filePath));
    transformer.transform(source, result);
}

// Processa ogni direttiva
function processDirective(document_server_xml, document_context_xml, directive) {
    var parts = directive.split(':', 2);
    if (parts.length != 2) {
        print('Invalid directive: ' + directive);
        return;
    }

    var xpath = parts[0].trim();
    var idx = directive.indexOf(':')
    var remaining = directive.slice(idx+1).trim()
    print(" remaining="+remaining)
    var operationAndParams = remaining.split(/\s+/,2);
    //print('operationAndParams='+operationAndParams)


    var operation = operationAndParams[0].trim();
    var onlyParams = remaining.slice(operation.length)
    print('onlyParams='+onlyParams)
    var params = {};
    if (onlyParams.length > 0) {      
        var paramPairs = onlyParams.split(',');
        print ('#params='+paramPairs.length)
        for (var i = 0; i < paramPairs.length; i++) {
            var pair = paramPairs[i].split('=');
            if (pair.length == 2) {
                print ('params[' + pair[0].trim() +'] = '+ pair[1].trim())
                params[pair[0].trim()] = pair[1].trim();
            } else if (pair.length > 2) {
                var idx = paramPairs[i].indexOf('=')
                var parremain = paramPairs[i].slice(idx+1)
                print ('params[' + pair[0].trim() +'] = '+ parremain.trim())
                params[pair[0].trim()] = parremain.trim();
            } else  {
                print('anaomalia parsing parametri')
            }
        }
    }
    var document = (xpath.startsWith('/Context')) ? document_context_xml : document_server_xml;

    switch (operation) {
        case 'add':
            addElement(document, xpath, params);
            break;
        // 'append' e' un alias del comando 'add'
        case 'append':
            addElement(document, xpath, params);
            break;
        case "top":
            addElementAtTop(document, xpath, params);
            break;
        case 'delete':
            deleteElement(document, xpath);
            break;
        case 'write-attribute':
            writeAttribute(document, xpath, params);
            break;
        case 'read-attribute':
            readAttribute(document, xpath, params);
            break;
        default:
            print('Unsupported operation: ' + operation);
    }
}

// Aggiungi un nuovo elemento come ultimo figlio
function addElement(document, xpath, attributes) {
    var parentXpath = xpath.substring(0, xpath.lastIndexOf('/'));
    var elementName = xpath.substring(xpath.lastIndexOf('/') + 1);

    var parent = getElementByXPath(document, parentXpath);
    if (!parent) {
        print('XPath not found: ' + parentXpath);
        return;
    }

    var newElement = document.createElement(elementName);
    for (var key in attributes) {
        newElement.setAttribute(key, attributes[key]);
    }
    parent.appendChild(newElement);
}

// Aggiungi un nuovo elemento come primo figlio
function addElementAtTop(document, xpath, attributes) {
    var parentXpath = xpath.substring(0, xpath.lastIndexOf('/'));
    var elementName = xpath.substring(xpath.lastIndexOf('/') + 1);

    var parent = getElementByXPath(document, parentXpath);
    if (!parent) {
        print("XPath not found: " + parentXpath);
        return;
    }

    var newElement = document.createElement(elementName);
    for (var key in attributes) {
        newElement.setAttribute(key, attributes[key]);
    }

    // Inserisce il nuovo elemento come primo figlio
    var firstChild = parent.getFirstChild();
    parent.insertBefore(newElement, firstChild);
}

// Elimina un elemento
function deleteElement(document, xpath) {
    var element = getElementByXPath(document, xpath);
    if (element) {
        element.getParentNode().removeChild(element);
    } else {
        print('XPath not found: ' + xpath);
    }
}

// Scrivi attributi a un elemento
function writeAttribute(document, xpath, attributes) {
    var element = getElementByXPath(document, xpath);
    if (!element) {
        print('XPath not found: ' + xpath);
        return;
    }

    for (var key in attributes) {
        element.setAttribute(key, attributes[key]);
    }
}

// Leggi attributi da un elemento
function readAttribute(document, xpath, attributes) {
    var element = getElementByXPath(document, xpath);
    if (!element) {
        print('XPath not found: ' + xpath);
        return;
    }

    for (var key in attributes) {
        print(key + ' = ' + element.getAttribute(key));
    }
}

// Helper per ottenere un elemento tramite XPath
function getElementByXPath(document, xpath) {
    var xPathFactory = XPathFactory.newInstance();
    var xPath = xPathFactory.newXPath();
    var expr = xPath.compile(xpath);
    return expr.evaluate(document, XPathConstants.NODE);
}

// Esegui il programma
var inputFilePath = arguments[0];
modifyTomcatConfig(inputFilePath);
