# idorg-ontology
Develop an ontology for Identifiers.org URI

How to convert:

```sh
% curl http://www.ebi.ac.uk/miriam/main/export/xml/ > resources_all.xml
% gem install nokogiri
% ruby miriam-xml2owl.rb resources_all.xml > resources_all.owl
```

References:
* http://wiki.lifesciencedb.jp/mw/SPARQLthon46/idorg-ontology
