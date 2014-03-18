require 'amatch'

class CoreferenceResolutionTask < Base
  @queue = :coreference_resolution_task
  @msg = "Resolviendo correferencias"

  attr_reader :document, :user

  TWO_WORDS_SIMILARITY = 0.92
  ONE_WORD_SIMILARITY  = 0.95

  def self.perform(document_id)
    self.new(document_id).call
  end

  def initialize(document_id)
    @document = Document.find(document_id)
    @user = @document.user
  end

  def call
    document.people.destroy_all
    named_entities = document.people_found.to_a
    find_duplicates(named_entities).each do |group|
      group.each { |named_entity| store(named_entity, group.length) }
    end
    document.context(force: true)
  end

  def store(named_entity, mentions=1)
    person = user.people.where(name: named_entity.text).first
    if person
      person.mentions = person.mentions.merge({document.id.to_s => mentions})
      person.save
    else
      person = Person.create name: named_entity.text,
                             mentions: { document.id.to_s => mentions},
                             lemma: named_entity.lemma
      user.people << person
    end
    named_entity.update_attribute :entity_id, person.id
    document.people << person
  end

  def find_duplicates(named_entities)
    @duplicates ||= []
    if @duplicates.empty?
      while !named_entities.empty?
        named_entity = named_entities.shift

        group = named_entities.select do |ne|
          if APP_ENV == "development"
            named_entity.text.downcase == ne.text.downcase
          else
            if named_entity.text.split(' ').length > 1
              jarowinkler_distance(named_entity.text, ne.text)
            else
              branting_distance(named_entity.text, ne.text)
            end
          end
        end

        named_entities.reject! { |ne| group.include?(ne) }
        @duplicates << group.append(named_entity)
      end
      @duplicates
    else
      @duplicates
    end
  end

  def jarowinkler_distance(a, b)
    jw = Amatch::JaroWinkler.new(a)
    jw.match(b) > ONE_WORD_SIMILARITY
  end

  def branting_distance(a, b)
    as, bs = [a, b].map { |w| w.split(" ") }
    shortest, longest = [as, bs].sort_by(&:size)
    scores = shortest.map do |a|
      jw = Amatch::JaroWinkler.new(a)
      scores = longest.map { |b| jw.match(b) }
      scores.max
    end
    scores.sum / shortest.size > TWO_WORDS_SIMILARITY
  end
end
