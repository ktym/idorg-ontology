#!/usr/bin/env ruby
#
# Convert MIRIAM Registry XML file (http://www.ebi.ac.uk/miriam/main/export/)
# to OWL for the Identifiers.org service.
#
# Copyright (C) 2016 Toshiaki Katayama <ktym@dbcls.jp>
#
# Pre requirements:
#  % curl http://www.ebi.ac.uk/miriam/main/export/xml/ > resources_all.xml
#  % gem install nokogiri
#  % miriam-xml2owl.rb resources_all.xml > resources_all.owl
#

require 'rubygems'
require 'nokogiri'
require 'csv'

template = DATA.read
databases = []

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
      :MIRIAM       =>  datatype["id"],
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

    $stderr.puts "Warning: #{hash[:URIs]} contains quote in #{hash[:Definition]}" if hash[:Definition][/\"/]

    databases.push [
      hash[:URIs].chomp('/'),
      hash[:Name],
      hash[:Definition].gsub('"', '\\"'),
      hash[:MIRIAM].sub(/^MIR:/, '')
    ]
  end
end

# @prefix dcat: <http://www.w3.org/ns/dcat#> .
# @prefix mirc: <http://identifiers.org/miriam.collection/MIR:> .
# @prefix mirr: <http://identifiers.org/miriam.resource/MIR:> .

puts HEADER = '# Identifiers.org ontology
@prefix :     <http://rdf.identifiers.org/ontology> .
@prefix owl:  <http://www.w3.org/2002/07/owl#> .
@prefix rdf:  <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix xsd:  <http://www.w3.org/2001/XMLSchema#> .
@prefix dct:  <http://purl.org/dc/terms/> .
@prefix sio:  <http://semanticscience.org/resource/> .
@prefix mir:  <http://identifiers.org/miriam.collection/MIR:> .

<http://rdf.identifiers.org/ontology>
    rdf:type owl:Ontology ;
    dct:license <http://creativecommons.org/publicdomain/zero/1.0/> ;
    owl:versionInfo "Created on 2016-07-25"^^xsd:string .

:DatabaseEntry
    rdf:type owl:Class ;
    owl:subClassOf  sio:SIO_000756 .    # sio:DatabaseEntry

:Database
    rdf:type owl:Class ;
    owl:subClassOf  sio:SIO_000089 .    # sio:Dataset

:entryOf
    rdfs:domain  :DatabaseEntry ;       # sio:DatabaseEntry
    rdfs:range   :Database ;            # sio:Database
    owl:subPropertyOf sio:SIO_000068 .  # sio:is-part-of (or sio:SIO_001278 is-data-item-in)

'

databases.sort.uniq.each do |uri, label, comment, miriam|
  entry = template.clone
  entry.sub!('@uri', uri)
  entry.sub!('@label', label)
  entry.sub!('@comment', comment)
  entry.sub!('@miriam', miriam)
  puts entry
end

__END__

<@uri>
    rdf:type :Database ;
    rdfs:label "@label" ;
    rdfs:comment "@comment" ;
    dct:source mir:@miriam .

