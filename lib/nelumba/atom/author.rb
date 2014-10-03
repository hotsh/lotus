module Nelumba
  require 'atom'

  module Atom
    # Holds information about the author of the Feed.
    class Author < ::Atom::Person
      require 'date'

      include ::Atom::SimpleExtensions

      # The XML namespace the specifies this content.
      POCO_NAMESPACE = 'http://portablecontacts.net/spec/1.0'

      # The XML namespace that identifies the conforming specification.
      ACTIVITY_NAMESPACE = 'http://activitystrea.ms/spec/1.0/'

      add_extension_namespace :activity, ACTIVITY_NAMESPACE
      element 'activity:object-type'

      namespace ::Atom::NAMESPACE
      element :email
      element :uri

      elements :links, :class => ::Atom::Link

      add_extension_namespace :poco, POCO_NAMESPACE
      element 'poco:id'
      element 'poco:organization', :class => Nelumba::Atom::Organization
      element 'poco:address',      :class => Nelumba::Atom::Address
      element 'poco:account',      :class => Nelumba::Atom::Account
      element 'poco:displayName'
      element 'poco:nickname'
      element 'poco:updated',     :class => DateTime, :content_only => true
      element 'poco:published',   :class => DateTime, :content_only => true
      element 'poco:birthday',    :class => Date,     :content_only => true
      element 'poco:anniversary', :class => Date,     :content_only => true
      element 'poco:gender'
      element 'poco:note'
      element 'poco:preferredUsername'

      element 'pronoun'

      # unfortunately ratom doesn't handle elements with the same local name well.
      # this is a workaround for that.
      attr_writer :name, :poco_name

      def name
        @name or self[::Atom::NAMESPACE, 'name'].first
      end

      def poco_name
        return @poco_name if @poco_name
        name = self[POCO_NAMESPACE, 'name'].first
        if name
          name = "<name>#{name}</name>"
          reader = XML::Reader.string(name)
          reader.read
          reader.read
          Nelumba::Atom::Name.new(reader)
        else
          nil
        end
      end

      def to_xml(*args)
        x = super(true)

        if self.name
          node = XML::Node.new('name')
          node << self.name
          x << node
        end

        if self.poco_name
          x << self.poco_name.to_xml(true, root_name = 'poco:name')
        end

        x
      end

      def initialize *args
        self.activity_object_type = "http://activitystrea.ms/schema/1.0/person"
        super(*args)
      end

      # Gives an instance of an Nelumba::Activity that parses the fields
      # having an activity prefix.
      def activity
        Nelumba::Activity.new(self)
      end

      def self.from_canonical(obj)
        hash = obj.to_hash
        hash.keys.each do |k|
          to_k = k
          if k == :display_name
            to_k = :displayName
          elsif k == :preferred_username
            to_k = :preferredUsername
          end

          if k == :extended_name
            if hash[:extended_name]
              hash[:"poco_name"] = Nelumba::Atom::Name.new(hash[:extended_name])
            end
            hash.delete :extended_name
          elsif k == :organization
            if hash[:organization]
              hash[:"poco_organization"] = Nelumba::Atom::Organization.new(hash[:organization])
            end
            hash.delete :organization
          elsif k == :address
            if hash[:address]
              hash[:"poco_address"] = Nelumba::Atom::Address.new(hash[:address])
            end
            hash.delete :address
          elsif k == :account
            if hash[:account]
              hash[:"poco_account"] = Nelumba::Atom::Account.new(hash[:account])
            end
            hash.delete :account
          elsif k == :uid
            if hash[:uid]
              hash[:"poco_id"] = hash[:uid]
            end
            hash.delete :uid
          elsif k == :pronoun
          elsif (k != :uri) && (k != :name) && (k != :email)
            hash[:"poco_#{to_k}"] = hash[k]
            hash.delete k
          end
        end

        # Remove any blank entries
        hash.keys.each do |key|
          if hash[key].nil? || hash[key] == ""
            hash.delete key
          end
        end

        self.new(hash)
      end

      def to_canonical
        organization = self.poco_organization
        organization = organization.to_canonical if organization

        address = self.poco_address
        address = address.to_canonical if address

        account = self.poco_account
        account = account.to_canonical if account

        ext_name = self.poco_name
        ext_name = ext_name.to_canonical if ext_name
        Nelumba::Person.new(:uid => self.poco_id,
                          :extended_name => ext_name,
                          :organization => organization,
                          :address => address,
                          :account => account,
                          :gender => self.poco_gender,
                          :note => self.poco_note,
                          :nickname => self.poco_nickname,
                          :display_name => self.poco_displayName,
                          :preferred_username => self.poco_preferredUsername,
                          :updated => self.poco_updated,
                          :published => self.poco_published,
                          :birthday => self.poco_birthday,
                          :anniversary => self.poco_anniversary,
                          :uri => self.uri,
                          :email => self.email,
                          :name => self.name)
      end
    end
  end
end
