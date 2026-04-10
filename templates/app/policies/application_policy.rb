class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    true
  end

  def show?
    true
  end

  def create?
    user.present?
  end

  def new?
    create?
  end

  def update?
    owner_or_admin?
  end

  def edit?
    update?
  end

  def destroy?
    admin?
  end

  private

  def admin?
    user&.admin?
  end

  def owner_or_admin?
    admin? || owner?
  end

  def owner?
    record.respond_to?(:user_id) && record.user_id == user&.id
  end

  class Scope
    attr_reader :user, :scope

    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      if user&.admin?
        scope.all
      else
        scope.none
      end
    end
  end
end
