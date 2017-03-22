#!/usr/bin/env ruby
#
# Convert MIRIAM Registry XML file (http://www.ebi.ac.uk/miriam/main/export/)
# to OWL for the Identifiers.org service.
#
# Copyright (C) 2016, 2017 Toshiaki Katayama <ktym@dbcls.jp>
#
# Pre requirements:
#  % curl http://www.ebi.ac.uk/miriam/main/export/xml/ > resources_all.xml
#  % gem install nokogiri
#  % ruby miriam-xml2owl.rb resources_all.xml > resources_all.owl
#

require 'rubygems'
require 'nokogiri'
require 'csv'

databases = {}

xml = Nokogiri::XML(ARGF)

ns = xml.namespaces

xml.xpath('//xmlns:datatype', ns).each do |datatype|
  next if datatype["obsolete"] == "true"

  path = './/xmlns:resources/xmlns:resource'
  datatype.xpath(path, ns).each do |res|
    res_id = res["id"]
    res_state = res["state"]
    res_reliability = res["reliability"]
    res_url = res.at('dataResource').content
    res_link = res.at('dataEntry').content
    res_example = res.at('dataEntityExample').content
    res_info = res.at('dataInfo').content
    res_institution = res.at('dataInstitution').content
    res_location = res.at('dataLocation').content

    path = './/xmlns:synonyms/xmlns:synonym'
    synonyms = datatype.xpath(path, ns).collect(&:text)

    path = './/xmlns:uris/xmlns:uri[@type="URN"]'
    path2 = './/xmlns:uris/xmlns:uri[@deprecated="true"]'
    urns = datatype.xpath(path, ns).collect(&:text) - datatype.xpath(path2, ns).collect(&:text)

    path = './/xmlns:uris/xmlns:uri[@type="URL"]'
    path2 = './/xmlns:uris/xmlns:uri[@deprecated="true"]'
    uris = datatype.xpath(path, ns).collect(&:text) - datatype.xpath(path2, ns).collect(&:text)

    path = './/xmlns:tags/xmlns:tag'
    tags = datatype.xpath(path, ns).collect(&:text)

    path = './/xmlns:annotation/xmlns:format[@name="SBML"]/xmlns:elements/xmlns:element'
    sbml = datatype.xpath(path, ns).collect(&:text)

    path = './/xmlns:documentations/xmlns:documentation[@type="PMID"]'
    pmids = datatype.xpath(path, ns).collect(&:text).map {|x| x[/\d+/]}

    path = './/xmlns:documentations/xmlns:documentation[@type="URL"]'
    urls = datatype.xpath(path, ns).collect(&:text)

    hash = {
      :Collection   =>  datatype["id"],
      :Namespace    =>  datatype.at('namespace').content,
      :Pattern      =>  datatype["pattern"],
      :Name         =>  datatype.at('name').content,
      :Synonyms     =>  synonyms.join("; "),
      :Definition   =>  datatype.at('definition').content,
      :URNs         =>  urns.join("\n"),
      :URIs         =>  uris.join("\n"),
      :Tags         =>  tags.join("; "),
      :SBML         =>  sbml.join("; "),
      :PMIDs        =>  pmids.join("\n"),
      :URLs         =>  urls.join("\n"),
      :Resource     =>  res_id,
      :State        =>  res_state,
      :Reliability  =>  res_reliability,
      :URL          =>  res_url,
      :Link         =>  res_link,
      :Example      =>  res_example,
      :Info         =>  res_info,
      :Institution  =>  res_institution,
      :Location     =>  res_location,
    }

    $stderr.puts "Warning: #{hash[:URIs]} contains quote in #{hash[:Definition]}" if hash[:Definition][/\"/] if $DEBUG

    namespace = hash[:Namespace]
    res_key = hash[:URL].strip
    res_val = hash[:Resource].sub(/^MIR:/, '')

    unless databases[namespace]
      databases[namespace] = {
        :uri => hash[:URIs].chomp('/'),
        :label => hash[:Name],
        :comment => hash[:Definition].gsub("\n", " ").gsub('"', '\\"').strip,
        :mirc => hash[:Collection].sub(/^MIR:/, ''),
        :resources => { res_key => res_val }
      }
    else
      databases[namespace][:resources][res_key] = res_val
    end
  end
end

# @prefix dcat: <http://www.w3.org/ns/dcat#> .

puts HEADER = '# Identifiers.org ontology
@prefix :     <http://rdf.identifiers.org/ontology/> .
@prefix owl:  <http://www.w3.org/2002/07/owl#> .
@prefix rdf:  <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix xsd:  <http://www.w3.org/2001/XMLSchema#> .
@prefix dct:  <http://purl.org/dc/terms/> .
@prefix foaf: <http://xmlns.com/foaf/0.1/> .
@prefix sio:  <http://semanticscience.org/resource/> .
@prefix mirc: <http://identifiers.org/miriam.collection/MIR:> .
@prefix mirr: <http://identifiers.org/miriam.resource/MIR:> .

<http://rdf.identifiers.org/ontology/>
    rdf:type            owl:Ontology ;
    rdfs:label          "Identifiers.org ontology" ;
    rdfs:comment        "Ontology for describing databases and entries in the Identifiers.org repository." ;
    dct:license         <http://creativecommons.org/publicdomain/zero/1.0/> ;
    owl:versionInfo     "Created on @DATE_GENERATED@"^^xsd:string .

:DatabaseEntry
    rdf:type            owl:Class ;
    rdfs:label          "Entry" ;
    rdfs:comment        "An instance of a database entry described with an Identifiers.org URI." ;
    owl:subClassOf      sio:SIO_000756 .        # sio:DatabaseEntry

:Database
    rdf:type            owl:Class ;
    rdfs:label          "Database" ;
    rdfs:comment        "An instance of a database described with an Identifiers.org URI." ;
    owl:subClassOf      sio:SIO_000089 .        # sio:Dataset

:database
    rdf:type            owl:ObjectProperty ;
    rdfs:label          "is entry of" ;
    rdfs:comment        "A predicate for describing that a DatabaseEntry belongs to a Database." ;
    rdfs:domain        :DatabaseEntry ;
    rdfs:range         :Database ;
    owl:subPropertyOf  sio:SIO_000068 .         # sio:is-part-of (or sio:SIO_001278 is-data-item-in)

'.sub('@DATE_GENERATED@', Time.now.strftime('%Y-%m-%d'))

DATABASE = '
<@uri>
    rdf:type :Database ;
    rdfs:label "@label" ;
    rdfs:comment "@comment" ;
    dct:source mirc:@miriam.collection ;
    foaf:homepage @resources .
'

#    dct:references @resources .

RESOURCE = '
<@url>
    dct:publisher mirr:@miriam.resource .
'

databases.sort.each do |namespace, hash|
  database = DATABASE.clone
  database.sub!('@uri', hash[:uri])
  database.sub!('@label', hash[:label])
  database.sub!('@comment', hash[:comment])
  database.sub!('@miriam.collection', hash[:mirc])
  database.sub!('@resources', hash[:resources].keys.map{|x| "<#{x}>"}.join(', '))
  puts database

  hash[:resources].each do |url, mirr|
    resource = RESOURCE.clone
    resource.sub!('@url', url)
    resource.sub!('@miriam.resource', mirr)
    puts resource
  end
end
