class PollParticipation < ActiveRecord::Base
  include Diaspora::Federated::Base
  include Diaspora::Fields::Guid
  include Diaspora::Fields::Author
  include Diaspora::Relayable

  belongs_to :poll
  belongs_to :poll_answer, counter_cache: :vote_count

  alias_attribute :parent, :poll

  validates :poll_answer, presence: true
  validate :not_already_participated

  def poll_answer_guid=(new_poll_answer_guid)
    self.poll_answer_id = PollAnswer.where(guid: new_poll_answer_guid).ids.first
  end

  def not_already_participated
    return if poll.nil?

    other_participations = PollParticipation.where(author_id: self.author.id, poll_id: self.poll.id).to_a-[self]
    if other_participations.present?
      self.errors.add(:poll, I18n.t("activerecord.errors.models.poll_participation.attributes.poll.already_participated"))
    end
  end

  class Generator < Diaspora::Federated::Generator
    def self.federated_class
      PollParticipation
    end

    def initialize(person, target, poll_answer)
      @poll_answer = poll_answer
      super(person, target)
    end

    def relayable_options
      {:poll => @target.poll, :poll_answer => @poll_answer}
    end
  end
end
