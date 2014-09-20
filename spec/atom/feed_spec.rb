require_relative '../helper'
require_relative '../../lib/nelumba/feed.rb'
require_relative '../../lib/nelumba/atom/feed.rb'

# Sanity checks on atom generation because I don't trust ratom completely.
#
# Since I can't be completely sure how to test the implementations since they
# are patchy inheritance, I'll just do big acceptance tests and overtest.
# Somehow, these are still really fast.
describe Nelumba::Atom do
  before do
    author = Nelumba::Person.new(:uri               => "http://example.com/users/1",
                               :email             => "user@example.com",
                               :name              => "wilkie",
                               :uid => "1",
                               :nickname    => "wilkie",
                               :extended_name     => {:formatted => "Dave Wilkinson",
                                 :family_name => "Wilkinson",
                                 :given_name => "Dave",
                                 :middle_name => "William",
                                 :honorific_prefix => "Mr.",
                                 :honorific_suffix => "II"},
                               :address => {:formatted => "123 Cherry Lane\nFoobar, PA, USA\n15206",
                                 :street_address => "123 Cherry Lane",
                                 :locality => "Foobar",
                                 :region => "PA",
                                 :postal_code => "15206",
                                 :country => "USA"},
                               :organization => {:name => "Hackers of the Severed Hand",
                                 :department => "Making Shit",
                                 :title => "Founder",
                                 :type => "open source",
                                 :start_date => Date.today,
                                 :end_date => Date.today,
                                 :location => "everywhere",
                                 :description => "I make ostatus work"},
                               :account     => {:domain => "example.com",
                                 :username => "wilkie",
                                 :userid => "1"},
                                 :gender      => "androgynous",
                                 :note        => "cool dude",
                                 :display_name => "Dave Wilkinson",
                                 :preferred_username => "wilkie",
                                 :updated     => Time.now,
                                 :published   => Time.now,
                                 :birthday    => Date.today,
                                 :anniversary => Date.today)

    source_feed = Nelumba::Feed.new(:title => "moo",
                                  :authors => [author],
                                  :rights => "CC")

    reply_to = Nelumba::Activity.new(:type  => :note,
                                   :actor => author,
                                   :object => Nelumba::Note.new(
                                     :title => "My First Entry",
                                     :html => "Hello"),
                                   :uid => "54321",
                                   :url => "http://example.com/entries/1",
                                   :published => Time.now,
                                   :updated => Time.now)

    entry = Nelumba::Activity.new(:actor => author,
                                :type => :note,
                                :object => Nelumba::Note.new(
                                  :title => "My Entry",
                                  :html => "Hello"),
                                :source => source_feed,
                                :uid => "54321",
                                :url => "http://example.com/entries/1",
                                :published => Time.now,
                                :in_reply_to => reply_to,
                                :updated => Time.now)

    @master = Nelumba::Feed.new(:title => "My Feed",
                              :title_type => "html",
                              :subtitle => "Subtitle",
                              :subtitle_type => "html",
                              :url => "http://example.com/feeds/1",
                              :rights => "CC0",
                              :icon => "http://example.com/icon.png",
                              :logo => "http://example.com/logo.png",
                              :hubs => ["http://hub.example.com",
                                        "http://hub2.example.com"],
                              :published => Time.now,
                              :updated => Time.now,
                              :authors => [author],
                              :items => [entry],
                              :uid => "12345")
  end

  it "should be able to reform canonical structure using Atom" do
    xml = Nelumba::Atom::Feed.from_canonical(@master).to_xml
    new_feed = Nelumba::Atom::Feed.new(XML::Reader.string(xml)).to_canonical

    old_hash = @master.to_hash
    new_hash = new_feed.to_hash

    old_hash[:authors] = old_hash[:authors].map(&:to_hash)
    new_hash[:authors] = new_hash[:authors].map(&:to_hash)

    old_hash[:items] = old_hash[:items].map(&:to_hash)
    new_hash[:items] = new_hash[:items].map(&:to_hash)

    old_hash[:items][0][:in_reply_to] = []
    new_hash[:items][0][:in_reply_to] = []

    old_hash[:items][0][:actor] = old_hash[:items][0][:actor].to_hash
    new_hash[:items][0][:actor] = new_hash[:items][0][:actor].to_hash

    old_hash[:items][0][:source] = old_hash[:items][0][:source].to_hash
    new_hash[:items][0][:source] = new_hash[:items][0][:source].to_hash

    old_hash[:items][0][:object] = old_hash[:items][0][:object].to_hash
    new_hash[:items][0][:object] = new_hash[:items][0][:object].to_hash

    old_hash[:items][0][:source][:authors] = old_hash[:items][0][:source][:authors].map(&:to_hash)
    new_hash[:items][0][:source][:authors] = new_hash[:items][0][:source][:authors].map(&:to_hash)

    # Flatten all keys to their to_s
    # We want to compare the to_s for all keys
    def flatten_keys!(hash)
      hash.keys.each do |k|
        if hash[k].is_a? Array
          # Go inside arrays (doesn't handle arrays of arrays)
          hash[k].map! do |e|
            if e.is_a? Hash
              flatten_keys! e
              e
            else
              e.to_s
            end
          end
        elsif hash[k].is_a? Hash
          # Go inside hashes
          flatten_keys!(hash[k])
        elsif hash[k].is_a? Time
          # Ensure all Time classes become DateTimes for comparison
          hash[k] = hash[k].to_datetime.to_s
        else
          # Ensure all fields become Strings
          hash[k] = hash[k].to_s
        end
      end
    end

    flatten_keys!(old_hash)
    flatten_keys!(new_hash)

    old_hash.must_equal new_hash
  end

  describe "<xml>" do
    before do
      @xml_str = Nelumba::Atom::Feed.from_canonical(@master).to_xml
      @xml = XML::Parser.string(@xml_str).parse
    end

    it "should publish a version of 1.0" do
      @xml_str.must_match /^<\?xml[^>]*\sversion="1\.0"/
    end

    it "should encode in utf-8" do
      @xml_str.must_match /^<\?xml[^>]*\sencoding="UTF-8"/
    end

    describe "<feed>" do
      before do
        @feed = @xml.root
      end

      it "should contain the Atom namespace" do
        @feed.namespaces.find_by_href("http://www.w3.org/2005/Atom").to_s
          .must_equal "http://www.w3.org/2005/Atom"
      end

      it "should contain the PortableContacts namespace" do
        @feed.namespaces.find_by_prefix('poco').to_s
          .must_equal "poco:http://portablecontacts.net/spec/1.0"
      end

      it "should contain the ActivityStreams namespace" do
        @feed.namespaces.find_by_prefix('activity').to_s
          .must_equal "activity:http://activitystrea.ms/spec/1.0/"
      end

      describe "<id>" do
        it "should contain the id from Nelumba::Feed" do
          @feed.find_first('xmlns:id', 'xmlns:http://www.w3.org/2005/Atom')
            .content.must_equal @master.uid
        end
      end

      describe "<rights>" do
        it "should contain the rights from Nelumba::Feed" do
          @feed.find_first('xmlns:rights', 'xmlns:http://www.w3.org/2005/Atom')
            .content.must_equal @master.rights
        end
      end

      describe "<logo>" do
        it "should contain the logo from Nelumba::Feed" do
          @feed.find_first('xmlns:logo', 'xmlns:http://www.w3.org/2005/Atom')
            .content.must_equal @master.logo
        end
      end

      describe "<icon>" do
        it "should contain the icon from Nelumba::Feed" do
          @feed.find_first('xmlns:icon', 'xmlns:http://www.w3.org/2005/Atom')
            .content.must_equal @master.icon
        end
      end

      describe "<published>" do
        it "should contain the time in the published field in Nelumba::Feed" do
          time = @feed.find_first('xmlns:published',
                                  'xmlns:http://www.w3.org/2005/Atom').content
          DateTime::rfc3339(time).to_s.must_equal @master.published.to_datetime.to_s
        end
      end

      describe "<updated>" do
        it "should contain the time in the updated field in Nelumba::Feed" do
          time = @feed.find_first('xmlns:updated',
                                  'xmlns:http://www.w3.org/2005/Atom').content
          DateTime::rfc3339(time).to_s.must_equal @master.updated.to_datetime.to_s
        end
      end

      describe "<link>" do
        it "should contain a link for the hub" do
          @feed.find_first('xmlns:link[@rel="hub"]',
                           'xmlns:http://www.w3.org/2005/Atom').attributes
             .get_attribute('href').value.must_equal(@master.hubs.first)
        end

        it "should allow a second link for the hub" do
          @feed.find('xmlns:link[@rel="hub"]',
                     'xmlns:http://www.w3.org/2005/Atom')[1].attributes
             .get_attribute('href').value.must_equal(@master.hubs[1])
        end

        it "should contain a link for self" do
          @feed.find_first('xmlns:link[@rel="self"]',
                           'xmlns:http://www.w3.org/2005/Atom').attributes
             .get_attribute('href').value.must_equal(@master.url)
        end
      end

      describe "<title>" do
        before do
          @title = @feed.find_first('xmlns:title', 'xmlns:http://www.w3.org/2005/Atom')
        end

        it "should contain the title from Nelumba::Feed" do
          @title.content.must_equal @master.title
        end

        it "should contain the type attribute from Nelumba::Feed" do
          @title.attributes.get_attribute('type').value.must_equal @master.title_type
        end
      end

      describe "<subtitle>" do
        before do
          @subtitle = @feed.find_first('xmlns:subtitle', 'xmlns:http://www.w3.org/2005/Atom')
        end

        it "should contain the subtitle from Nelumba::Feed" do
          @subtitle.content.must_equal @master.subtitle
        end

        it "should contain the type attribute from Nelumba::Feed" do
          @subtitle.attributes.get_attribute('type').value.must_equal @master.subtitle_type
        end
      end

      describe "<author>" do
        before do
          @author = @feed.find_first('xmlns:author', 'xmlns:http://www.w3.org/2005/Atom')
        end

        describe "<activity:object-type>" do
          it "should identify this tag as a person object" do
            @author.find_first('activity:object-type').content
              .must_equal "http://activitystrea.ms/schema/1.0/person"
          end
        end

        describe "<email>" do
          it "should list the author's email" do
            @author.find_first('xmlns:email',
                               'xmlns:http://www.w3.org/2005/Atom').content.must_equal @master.authors.first.email
          end
        end

        describe "<uri>" do
          it "should list the author's uri" do
            @author.find_first('xmlns:uri',
                               'xmlns:http://www.w3.org/2005/Atom').content.must_equal @master.authors.first.uri
          end
        end

        describe "<name>" do
          it "should list the author's name" do
            @author.find_first('xmlns:name',
                               'xmlns:http://www.w3.org/2005/Atom').content.must_equal @master.authors.first.name
          end
        end

        describe "<poco:id>" do
          it "should list the author's portable contact id" do
            @author.find_first('poco:id',
                               'http://portablecontacts.net/spec/1.0').content.must_equal @master.authors.first.uid
          end
        end

        describe "<poco:name>" do
          before do
            @poco_name = @author.find_first('poco:name',
                                            'http://portablecontacts.net/spec/1.0')
          end

          describe "<formatted>" do
            it "should list the author's portable contact formatted name" do
              @poco_name.find_first('xmlns:formatted',
                                    'xmlns:http://www.w3.org/2005/Atom')
                .content.must_equal @master.authors.first.extended_name[:formatted]
            end
          end

          describe "<familyName>" do
            it "should list the author's portable contact family name" do
              @poco_name.find_first('xmlns:familyName',
                                    'xmlns:http://www.w3.org/2005/Atom')
                .content.must_equal @master.authors.first.extended_name[:family_name]
            end
          end

          describe "<givenName>" do
            it "should list the author's portable contact given name" do
              @poco_name.find_first('xmlns:givenName',
                                    'xmlns:http://www.w3.org/2005/Atom')
                .content.must_equal @master.authors.first.extended_name[:given_name]
            end
          end

          describe "<middleName>" do
            it "should list the author's portable contact middle name" do
              @poco_name.find_first('xmlns:middleName',
                                    'xmlns:http://www.w3.org/2005/Atom')
                .content.must_equal @master.authors.first.extended_name[:middle_name]
            end
          end

          describe "<honorificPrefix>" do
            it "should list the author's portable contact honorific prefix" do
              @poco_name.find_first('xmlns:honorificPrefix',
                                    'xmlns:http://www.w3.org/2005/Atom')
                .content.must_equal @master.authors.first.extended_name[:honorific_prefix]
            end
          end

          describe "<honorificSuffix>" do
            it "should list the author's portable contact honorific suffix" do
              @poco_name.find_first('xmlns:honorificSuffix',
                                    'xmlns:http://www.w3.org/2005/Atom')
                .content.must_equal @master.authors.first.extended_name[:honorific_suffix]
            end
          end
        end

        describe "<poco:organization>" do
          before do
            @poco_org = @author.find_first('poco:organization',
                                           'http://portablecontacts.net/spec/1.0')
          end

          describe "<name>" do
            it "should list the author's portable contact organization name" do
              @poco_org.find_first('xmlns:name',
                                   'xmlns:http://www.w3.org/2005/Atom')
                .content.must_equal @master.authors.first.organization[:name]
            end
          end

          describe "<department>" do
            it "should list the author's portable contact organization department" do
              @poco_org.find_first('xmlns:department',
                                   'xmlns:http://www.w3.org/2005/Atom')
                .content.must_equal @master.authors.first.organization[:department]
            end
          end

          describe "<title>" do
            it "should list the author's portable contact organization title" do
              @poco_org.find_first('xmlns:title',
                                   'xmlns:http://www.w3.org/2005/Atom')
                .content.must_equal @master.authors.first.organization[:title]
            end
          end

          describe "<type>" do
            it "should list the author's portable contact organization type" do
              @poco_org.find_first('xmlns:type',
                                   'xmlns:http://www.w3.org/2005/Atom')
                .content.must_equal @master.authors.first.organization[:type]
            end
          end

          describe "<startDate>" do
            it "should list the author's portable contact organization startDate" do
              time = @poco_org.find_first('xmlns:startDate',
                                          'xmlns:http://www.w3.org/2005/Atom').content
              DateTime::parse(time).to_s
                .must_equal @master.authors.first.organization[:start_date].to_datetime.to_s
            end
          end

          describe "<endDate>" do
            it "should list the author's portable contact organization endDate" do
              time = @poco_org.find_first('xmlns:endDate',
                                          'xmlns:http://www.w3.org/2005/Atom').content
              DateTime::parse(time).to_s
                .must_equal @master.authors.first.organization[:end_date].to_datetime.to_s
            end
          end

          describe "<location>" do
            it "should list the author's portable contact organization location" do
              @poco_org.find_first('xmlns:location',
                                   'xmlns:http://www.w3.org/2005/Atom')
                .content.must_equal @master.authors.first.organization[:location]
            end
          end

          describe "<description>" do
            it "should list the author's portable contact organization description" do
              @poco_org.find_first('xmlns:description',
                                   'xmlns:http://www.w3.org/2005/Atom')
                .content.must_equal @master.authors.first.organization[:description]
            end
          end
        end

        describe "<poco:address>" do
          before do
            @poco_address = @author.find_first('poco:address',
                                               'http://portablecontacts.net/spec/1.0')
          end

          describe "<formatted>" do
            it "should list the author's portable contact formatted address" do
              @poco_address.find_first('xmlns:formatted',
                                       'xmlns:http://www.w3.org/2005/Atom')
                .content.must_equal @master.authors.first.address[:formatted]
            end
          end

          describe "<streetAddress>" do
            it "should list the author's portable contact address streetAddress" do
              @poco_address.find_first('xmlns:streetAddress',
                                       'xmlns:http://www.w3.org/2005/Atom')
                .content.must_equal @master.authors.first.address[:street_address]
            end
          end

          describe "<locality>" do
            it "should list the author's portable contact address locality" do
              @poco_address.find_first('xmlns:locality',
                                       'xmlns:http://www.w3.org/2005/Atom')
                .content.must_equal @master.authors.first.address[:locality]
            end
          end

          describe "<region>" do
            it "should list the author's portable contact address region" do
              @poco_address.find_first('xmlns:region',
                                       'xmlns:http://www.w3.org/2005/Atom')
                .content.must_equal @master.authors.first.address[:region]
            end
          end

          describe "<postalCode>" do
            it "should list the author's portable contact address postalCode" do
              @poco_address.find_first('xmlns:postalCode',
                                       'xmlns:http://www.w3.org/2005/Atom')
                .content.must_equal @master.authors.first.address[:postal_code]
            end
          end

          describe "<country>" do
            it "should list the author's portable contact address country" do
              @poco_address.find_first('xmlns:country',
                                       'xmlns:http://www.w3.org/2005/Atom')
                .content.must_equal @master.authors.first.address[:country]
            end
          end
        end

        describe "<poco:account>" do
          before do
            @poco_account = @author.find_first('poco:account',
                                               'http://portablecontacts.net/spec/1.0')
          end

          describe "<domain>" do
            it "should list the author's portable contact account domain" do
              @poco_account.find_first('xmlns:domain',
                                       'xmlns:http://www.w3.org/2005/Atom')
                .content.must_equal @master.authors.first.account[:domain]
            end
          end

          describe "<username>" do
            it "should list the author's portable contact account username" do
              @poco_account.find_first('xmlns:username',
                                       'xmlns:http://www.w3.org/2005/Atom')
                .content.must_equal @master.authors.first.account[:username]
            end
          end

          describe "<userid>" do
            it "should list the author's portable contact account userid" do
              @poco_account.find_first('xmlns:userid',
                                       'xmlns:http://www.w3.org/2005/Atom')
                .content.must_equal @master.authors.first.account[:userid]
            end
          end
        end

        describe "<poco:displayName>" do
          it "should list the author's portable contact display name" do
            @author.find_first('poco:displayName',
                               'http://portablecontacts.net/spec/1.0')
              .content.must_equal @master.authors.first.display_name
          end
        end

        describe "<poco:nickname>" do
          it "should list the author's portable contact nickname" do
            @author.find_first('poco:nickname',
                               'http://portablecontacts.net/spec/1.0')
              .content.must_equal @master.authors.first.nickname
          end
        end

        describe "<poco:gender>" do
          it "should list the author's portable contact gender" do
            @author.find_first('poco:gender',
                               'http://portablecontacts.net/spec/1.0')
              .content.must_equal @master.authors.first.gender
          end
        end

        describe "<poco:note>" do
          it "should list the author's portable contact note" do
            @author.find_first('poco:note',
                               'http://portablecontacts.net/spec/1.0')
              .content.must_equal @master.authors.first.note
          end
        end

        describe "<poco:preferredUsername>" do
          it "should list the author's portable contact preferred username" do
            @author.find_first('poco:preferredUsername',
                               'http://portablecontacts.net/spec/1.0')
              .content.must_equal @master.authors.first.preferred_username
          end
        end

        describe "<poco:birthday>" do
          it "should list the author's portable contact birthday" do
            time = @author.find_first('poco:birthday',
                                      'http://portablecontacts.net/spec/1.0').content
            DateTime::parse(time).to_s.must_equal @master.authors.first
                                                       .birthday.to_datetime.to_s
          end
        end

        describe "<poco:anniversary>" do
          it "should list the author's portable contact anniversary" do
            time = @author.find_first('poco:anniversary',
                                      'http://portablecontacts.net/spec/1.0').content
            DateTime::parse(time).to_s.must_equal @master.authors.first
                                                       .anniversary.to_datetime.to_s
          end
        end

        describe "<poco:published>" do
          it "should list the author's portable contact published date" do
            time = @author.find_first('poco:published',
                                      'http://portablecontacts.net/spec/1.0').content
            DateTime::parse(time).to_s.must_equal @master.authors.first
                                                       .published.to_datetime.to_s
          end
        end

        describe "<poco:updated>" do
          it "should list the author's portable contact updated date" do
            time = @author.find_first('poco:updated',
                                      'http://portablecontacts.net/spec/1.0').content
            DateTime::parse(time).to_s.must_equal @master.authors.first
                                                       .updated.to_datetime.to_s
          end
        end
      end

      describe "<entry>" do
        before do
          @entry = @feed.find_first('xmlns:entry', 'xmlns:http://www.w3.org/2005/Atom')
        end

        it "should have the thread namespace" do
          @entry.namespaces.find_by_prefix('thr').to_s
            .must_equal "thr:http://purl.org/syndication/thread/1.0"
        end

        it "should have the activity streams namespace" do
          @entry.namespaces.find_by_prefix('activity').to_s
            .must_equal "activity:http://activitystrea.ms/spec/1.0/"
        end

        describe "<title>" do
          it "should contain the entry title" do
            @entry.find_first('xmlns:title', 'xmlns:http://www.w3.org/2005/Atom')
              .content.must_equal @master.items.first.object.title
          end
        end

        describe "<id>" do
          it "should contain the entry id" do
            @entry.find_first('xmlns:id', 'xmlns:http://www.w3.org/2005/Atom')
              .content.must_equal @master.items.first.uid
          end
        end

        describe "<link>" do
          it "should contain a link for self" do
            @entry.find_first('xmlns:link[@rel="self"]',
                              'xmlns:http://www.w3.org/2005/Atom').attributes
               .get_attribute('href').value.must_equal(@master.items.first.url)
          end
        end

        describe "<updated>" do
          it "should contain the entry updated date" do
            time = @entry.find_first('xmlns:updated',
                                     'xmlns:http://www.w3.org/2005/Atom').content
            DateTime.parse(time).to_s.must_equal @master.items.first.updated.to_datetime.to_s
          end
        end

        describe "<published>" do
          it "should contain the entry published date" do
            time = @entry.find_first('xmlns:published',
                                     'xmlns:http://www.w3.org/2005/Atom').content
            DateTime.parse(time).to_s.must_equal @master.items.first.published.to_datetime.to_s
          end
        end

        describe "<activity:object-type>" do
          it "should reflect the activity for this entry" do
            @entry.find_first('activity:object-type').content
              .must_equal "http://activitystrea.ms/schema/1.0/note"
          end
        end

        describe "<content>" do
          it "should contain the entry content" do
            @entry.find_first('xmlns:content', 'xmlns:http://www.w3.org/2005/Atom')
              .content.must_equal @master.items.first.object.html
          end

          it "should have the corresponding type attribute" do
            @entry.find_first('xmlns:content', 'xmlns:http://www.w3.org/2005/Atom')
              .attributes.get_attribute('type').value.must_equal "html"
          end
        end
      end
    end
  end
end
