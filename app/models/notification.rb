#   Copyright (c) 2010-2011, Diaspora Inc.  This file is
#   licensed under the Affero General Public License version 3 or later.  See
#   the COPYRIGHT file.
#
class Notification < ActiveRecord::Base
  belongs_to :recipient, class_name: "User"
  has_many :notification_actors, dependent: :destroy
  has_many :actors, class_name: "Person", through: :notification_actors, source: :person
  belongs_to :target, polymorphic: true

  attr_accessor :note_html

  def self.for(recipient, opts={})
    where(opts.merge!(recipient_id: recipient.id)).order("updated_at DESC")
  end

  def as_json(opts={})
    super(opts.merge(methods: :note_html))
  end

  def email_the_user(target, actor)
    recipient.mail(mail_job, recipient_id, actor.id, target.id)
  end

  def set_read_state( read_state )
    update_column(:unread, !read_state)
  end

  def mail_job
    raise NotImplementedError.new("Subclass this.")
  end

  def linked_object
    target
  end

  def self.concatenate_or_create(recipient, target, actor)
    return nil if suppress_notification?(recipient, target)

    find_or_initialize_by(recipient: recipient, target: target, unread: true).tap do |notification|
      notification.actors |= [actor]
      # Explicitly touch the notification to update updated_at whenever new actor is inserted in notification.
      if notification.new_record? || notification.changed?
        notification.save!
      else
        notification.touch
      end
    end
  end

  def self.create_notification(recipient_id, target, actor)
    create(recipient_id: recipient_id, target: target, actors: [actor])
  end

  private_class_method def self.suppress_notification?(recipient, post)
    post.is_a?(Post) && recipient.is_shareable_hidden?(post)
  end

  def self.types
    {
      "also_commented" => "Notifications::AlsoCommented",
      "comment_on_post" => "Notifications::CommentOnPost",
      "liked" => "Notifications::Liked",
      "mentioned" => "Notifications::Mentioned",
      "reshared" => "Notifications::Reshared",
      "started_sharing" => "Notifications::StartedSharing"
    }
  end
end
