# encoding: UTF-8

class BioTCM::Databases::HGNC
  #
  # Macro definitions
  #
  private

  def self.create_converters
    # Define #converter_list
    def converter_list
      { direct:@@direct_converters, indirect:@@indirect_converters }
    end
    # Define converters
    IDENTIFIERS.each_key do |src|
      IDENTIFIERS.each_key do |dst|
        next if src == dst
        sym = (src.to_s + "2" + dst.to_s).to_sym
        [src, dst].include?(:hgncid) ? create_direct_converter(sym) : create_indirect_converter(sym)
      end
    end
    return nil
  end

  def self.create_direct_converter(*syms)
    syms.each do |sym|
      class_variable_defined?(:@@direct_converters) ? @@direct_converters<<sym : @@direct_converters=[sym]
      class_eval %{
        def #{sym}(obj = nil)
          return @#{sym} unless obj
          return @#{sym}[obj.to_s].to_s rescue raise ArgumentError, "The parameter \\"\#{obj}\\"(\#{obj.class}) can't be converted into String"
        end
      }
      String.class_eval %{
        def #{sym}
          String.hgnc.#{sym}[self].to_s rescue raise "HGNC dictionary not given"
        end
        def #{sym}!
          replace(String.hgnc.#{sym}[self].to_s) rescue raise "HGNC dictionary not given"
        end
      }
      Array.class_eval %{
        def #{sym}
          self.collect do |item|
            item.to_s rescue raise ArgumentError, "The element \\"\#{item}\\"(\#{item.class}) in the Array can't be converted into String"
          end.collect { |item| item.#{sym} }
        end
        def #{sym}!
          self.collect! do |item|
            item.to_s rescue raise ArgumentError, "The element \\"\#{item}\\"(\#{item.class}) in the Array can't be converted into String"
          end.collect! { |item| item.#{sym} }
        end
      }
    end
    return nil
  end

  def self.create_indirect_converter(*syms)
    syms.each do |sym|
      class_variable_defined?(:@@indirect_converters) ? @@indirect_converters<<sym : @@indirect_converters=[sym]
      /^(?<src>[^2]+)2(?<dst>.+)$/ =~ sym.to_s
      class_eval %{
        def #{sym}(obj)
          return hgncid2#{dst}(#{src}2hgncid(obj)) rescue raise ArgumentError, "The parameter \\"\#{obj}\\"(\#{obj.class}) can't be converted into String"
        end
      }
      String.class_eval %{
        def #{sym}
          self.#{src}2hgncid.hgncid2#{dst}
        end
        def #{sym}!
          replace(self.#{src}2hgncid.hgncid2#{dst})
        end
      }
      Array.class_eval %{
        def #{sym}
          self.collect do |item|
            item.to_s rescue raise ArgumentError, "The element \\"\#{item}\\"(\#{item.class}) in the Array can't be converted into String"
          end.collect { |item| item.#{src}2hgncid.hgncid2#{dst} }
        end
        def #{sym}!
          self.collect! do |item|
            item.to_s rescue raise ArgumentError, "The element \\"\#{item}\\"(\#{item.class}) in the Array can't be converted into String"
          end.collect! { |item| item.#{src}2hgncid.hgncid2#{dst} }
        end
      }
    end
    return nil
  end
end

# HGNC object loads in any given HGNC flat file and builds 
# hashes storing the conversion pairs, using HGNC ID as the primary key.
#
# == Example Usage
#
# === Instantiation
# Create an HGNC using default downloaded table is the most common way. It 
# may take minutes to download the table at the first time.
#   hgnc = BioTCM::Databases::HGNC.new
#
# Or you want to create an instance with your own HGNC table.
#   hgnc = BioTCM::Databases::HGNC.new("path_to_your_table/hgnc_custom.txt")
#
# === Convert in hash way
# Using HGNC object in hash way is the most effective way but without symbol 
# rescue. (Direct converters only)
#   hgnc.entrez2hgncid["ASIC1"] # => "HGNC:100"
#   some_function(hgnc.entrez2hgncid["ASIC1"], other_params) unless hgnc.entrez2hgncid["ASIC1"].nil?
#
# Note that nil (not "") will be returned by hash if failed to index.
#   hgnc.symbol2hgncid["NOT_SYMBOL"] # => nil
#
# And the hash does not rescue symbols if fail to index.
#   hgnc.symbol2hgncid["ada"] # => nil
#
# === Convert in method way
# Using HGNC object to convert identifers in method way would rescue symbol 
# while costs a little more. 
#   hgnc.entrez2symbol("100") # => "ADA"
#   some_function(hgnc.entrez2symbol("100"), other_params) unless hgnc.entrez2symbol("100") == ""
#
# Note that empty String "" (not nil) will be returned if failed to convert.
#   hgnc.symbol2entrez["NOT_SYMBOL"] # => ""
#
# Method will rescue symbols if fail to query.
#   hgnc.symbol2entrez("ada") # => "100"
#
# === Convert String or Array
# Using extended String or Array is a more "Ruby" way (as far as I think). 
# Just claim an HGNC object as the dictionary at first.
#   BioDB::HGNC.new.as_dictionary
#
# Then miricles happen.
#   "100".entrez2symbol # => "ADA"
#   some_function("100".entrez2symbol, other_params) unless "100".entrez2symbol == ""
#
# Note that empty String "" (not nil) will be returned if fail to convert 
#   "NOT_SYMBOL".symbol2entrez # => ""
#   "NOT_SYMBOL".symbol2entrez.entrez2ensembl # => ""
#
# Have fun!
#   "APC".symbol2entrez.entrez2ensembl # => "ENSG00000134982"
#   ["APC", "IL1"].symbol2entrez # => ["324","3552"] 
#   nil.entrez2ensembl # NoMethodError
#
# == About HGNC Database
# The HUGO Gene Nomenclature Committee (HGNC) is the only worldwide authority 
# that assigns standardised nomenclature to human genes. For each known human 
# gene their approve a gene name and symbol (short-form abbreviation).  All 
# approved symbols are stored in the HGNC database. Each symbol is unique and 
# HGNC ensures that each gene is only given one approved gene symbol. 
#
# == Reference
# {http://www.genenames.org/ HUGO Gene Nomenclature Committee at the European Bioinformatics Institute}
class BioTCM::Databases::HGNC
  extend BioTCM::Modules::WorkingDir

  # Current version of HGNC
  VERSION = "0.2.0"
  # Meta key for the download url of default HGNC table
  META_KEY = "HGNC_DOWNLOAD_URL"
  # Identifers available in BioTCM::Databases::HGNC by now mapped to headline in HGNC table.
  # @note Single-item column comes first (at position 0) before multiple-item columns.
  IDENTIFIERS = {
    hgncid:"HGNC ID",
    symbol:["Approved Symbol", "Previous Symbols", "Synonyms"],
    entrez:"Entrez Gene ID(supplied by NCBI)",
    refseq:["RefSeq(supplied by NCBI)", "RefSeq IDs"],
    uniprot:"UniProt ID(supplied by UniProt)",
    ensembl:"Ensembl ID(supplied by Ensembl)",
  }

  # @!group Conversion method family
  # @!method converter_list
  #   List all HGNC conversion methods
  #   @return [Hash]
  #   @example
  #     hgnc.converter_list
  #     # => {:direct=>[:hgncid2symbol, ...], :indirect=>[:symbol2entrez, ...]}
  # @!method direct_converter(str)
  #   @overload direct_converter(str)
  #     Convert str
  #     @param [String]
  #     @return [String] "" for no result
  #     @example
  #       hgnc.symbol2hgncid("ASIC1") # => "HGNC:100"
  #       hgnc.symbol2hgncid("") # => ""
  #   @overload direct_converter
  #     Get the corresponding hash
  #     @return [Hash]
  #     @example
  #       hgnc.symbol2hgncid          # => {...}
  #       hgnc.symbol2hgncid["ASIC1"] # => "HGNC:100"
  # @!method indirect_converter(str)
  #   Convert str
  #   @param [String]
  #   @return [String] "" for no result
  #   @example
  #     hgnc.symbol2entrez("ASIC1") # => "41"
  #     hgnc.symbol2entrez["ASIC1"] # => ArgumentError
  create_converters
  # @!endgroup

  # Create a new HGNC object based on the given flat file or a downloaded one
  # if file_path is nil.
  # @param file_path [String] the path of your HGNC table files if default not used
  def initialize(file_path = nil)
    # Initialize instance variables
    self.rescue_symbol = true # Use setter to load @@rescue_history
    @rescue_method = :auto
    @@direct_converters.each { |sym| instance_variable_set("@" + sym.to_s, {}) }

    # Load HGNC table
    if file_path
      raise ArgumentError, "#{file_path} not exists" unless File.exists?(file_path)
    else
      # Load the default HGNC table (may download if in need)
      file_path = self.class.path_to("hgnc_set.txt")
      unless File.exists?(file_path)
        BioTCM.log.info("HGNC") { "Since default HGNC table not exists, trying to download one... (This may cost several minutes.)" }
        File.open(file_path, 'w:UTF-8').puts BioTCM.get(BioTCM.get_meta(META_KEY))
      end
    end    
    load_hgnc_table(File.open(file_path))
    
    BioTCM.log.debug("HGNC") { "New object " + self.inspect }
  end
  # Use self as the dictionary for String & Array extention
  # @return [self]
  def as_dictionary
    String.hgnc = self
  end
  # Returns true if rescue symbol
  # @return [Boolean]
  def rescue_symbol?
    @rescue_symbol
  end
  # When set to true, try to rescue unrecognized symbol (default is true)
  # @param boolean [Boolean]
  def rescue_symbol= (boolean)
    @rescue_symbol = (boolean ? true : false)

    # Load in rescue history if exists
    if @rescue_symbol && !self.class.class_variable_defined?(:@@rescue_history)
      @@rescue_history = {}
      @@rescue_history_filename = self.class.path_to("rescue_history.txt")
      if FileTest.exists?(@@rescue_history_filename)
        File.open(@@rescue_history_filename).each do |line|
          column = line.chomp.split("\t")
          @@rescue_history[column[0]] = column[1]
        end
      end
    end
    return @rescue_symbol
  end
  # Return current rescue method
  # @return [Symbol] :manual or :auto
  def rescue_method
    @rescue_method
  end
  # When set to :manual, user has to explain every new unrecognized symbol; 
  # otherwise, HGNC will try to do this by itself.
  # @param symbol [Symbol] :manual or :auto
  def rescue_method= (symbol)
    @rescue_method = (symbol == :manual ? :manual : :auto)
  end
  # Return the statistics hash
  # @return [Hash]
  # @example
  #   BioTCM::Databases::HGNC.new("test_set.txt").stat
  #   # => {"Gene Symbol"=>24, "Entrez ID"=>9, "Refseq ID"=>13, "Uniprot ID"=>9, "Ensembl ID"=>9}
  def stat
    unless @stat
      @stat = {}
      IDENTIFIERS.each_key do |id|
        id == :hgncid ? @stat[id] = @hgncid2symbol.size : @stat[id] = instance_variable_get("@" + id.to_s + "2hgncid").size
      end
    end
    @stat
  end
  # @private
  def inspect
    "#<BioTCM::Databases::HGNC @stat=#{stat.inspect}>"
  end
  # @private
  def to_s
    inspect
  end

  private

  # Load in the hgnc table from IO
  # @param fin [#gets, #each] Typically a File or IO
  def load_hgnc_table(fin)
    # Headline
    names = fin.gets.chomp.split("\t")
    index2identifier = {}
    index_hgncid = nil
    IDENTIFIERS.each do |identifer, name|
      if identifer == :hgncid
        index_hgncid = names.index(name)
      elsif name.is_a?(String)
        index2identifier[names.index(name)] = identifer if names.index(name)
      else
        # For each index, whose value in index2identifier is a
        #   Symbol,  will be mapped to single item
        #   String,  will be mapped to list item
        name.each_with_index { |n, i| index2identifier[names.index(n)] =  (i == 0 ? identifer : identifer.to_s) if names.index(n) }
      end
    end
    
    # Dynamically bulid a line processor
    process_one_line = index2identifier.collect { |index, identifer|
      if identifer.is_a?(Symbol) # Single
      %{
        unless column[#{index}] == nil || column[#{index}] == "" || column[#{index}] == "-"
          @#{identifer}2hgncid[column[#{index}]] = column[#{index_hgncid}]
          @hgncid2#{identifer}[column[#{index_hgncid}]] = column[#{index}]
        end }
      else # Array
      %{
        unless column[#{index}] == nil
          column[#{index}].split(", ").each { |id| @#{identifer}2hgncid[id] = column[#{index_hgncid}] if @#{identifer}2hgncid[id].nil? }
        end }
      end
    }.join

    # Content
    eval %{fin.each do |line|\n column = line.chomp.split("\\t")} + process_one_line + "end"
    return nil
  end
  # Try to rescue a gene symbol
  # @param symbol [String] Gene symbol
  # @param method [Symbol] :auto or :manual
  # @param rehearsal [Boolean] When set to true, neither outputing warnings nor modifying rescue history
  # @return [String] "" if rescue failed
  def rescue_symbol(symbol, method = @rescue_method, rehearsal = false)
    return @@rescue_history[symbol] if @@rescue_history[symbol]
    case method
    when :auto
      auto_rescue = ""
      if @symbol2hgncid[symbol.upcase]
        auto_rescue = symbol.upcase
      elsif @symbol2hgncid[symbol.gsub('-','')]
        auto_rescue = symbol.gsub('-','')
      elsif @symbol2hgncid[symbol.upcase.gsub('-','')]
        auto_rescue = symbol.upcase.gsub('-','')
      # Add more rules here
      end
      # Record
      unless rehearsal
        BioTCM.log.warn("HGNC") { "Unrecognized symbol \"#{symbol}\", \"#{auto_rescue}\" used instead" }
        @@rescue_history[symbol] = auto_rescue
      end
      return auto_rescue
    when :manual
      # Try automatic rescue first
      if (auto_rescue = rescue_symbol(symbol, :auto, true)) != ""
        print "\"#{symbol}\" unrecognized. Use \"#{auto_rescue}\" instead? [Yn] "
        unless gets.chomp == 'n'
          @@rescue_history[symbol] = auto_rescue unless rehearsal
          return auto_rescue
        end
      end
      # Manually rescue
      loop do
        print "Please correct \"#{symbol}\" or press enter directly to return empty String instead:\n"
        unless (manual_rescue = gets.chomp) == "" || @symbol2hgncid[manual_rescue]
          puts "Failed to recognize \"#{manual_rescue}\""
          next
        end
        @@rescue_history[symbol] = manual_rescue unless rehearsal
        File.open(@@rescue_history_filename, "a").print(symbol, "\t", manual_rescue, "\n") unless rehearsal
        return manual_rescue
      end
    end
  end

  #
  # Overwrite some methods to provide symbol rescue funtion
  # Use class_eval to ensure not documented by YARD
  #
  class_eval do
    def symbol2hgncid(symbol = nil)
      return @symbol2hgncid unless symbol
      begin
        @symbol2hgncid.fetch(symbol)
      rescue KeyError
        return "" if symbol == "" || !@rescue_symbol
        @symbol2hgncid[rescue_symbol(symbol)].to_s
      end
    end
  end
  # Use method way other than hash way to introduce rescue function
  String.class_eval do
    def symbol2hgncid
      String.hgnc.symbol2hgncid(self) rescue raise "HGNC dictionary not given"
    end
    def symbol2hgncid!
      replace(String.hgnc.symbol2hgncid(self)) rescue raise "HGNC dictionary not given"
    end
  end
end

class String
  # Get the HGNC dictionary for conversion
  # @return [BioTCM::Databases::HGNC]
  def self.hgnc
    @hgnc
  end
  # @overload hgnc=(obj)
  #   Set the HGNC dictionary for conversion
  #   @param [BioTCM::Databases::HGNC] obj
  # @overload hgnc=(nil)
  #   Deregister the HGNC dictionary
  #   @param [nil]
  # @raise ArgumentError Raised if neither HGNC object nor nil given
  def self.hgnc=(obj)
    if obj == nil
      @hgnc = nil
    else
      raise ArgumentError, "Not a HGNC object" unless obj.is_a?(BioTCM::Databases::HGNC)
      @hgnc = obj
    end
  end
end

BioTCM::Databases::HGNC.wd = BioTCM.path_to("data/hgnc")
