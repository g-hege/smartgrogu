class Ability
  include CanCan::Ability

  def initialize(user)
    can [:read, :create, :update, :destroy], Article
    can [:update, :destroy], Article, user: user
#    can [:read, :create, :update, :destroy], Movie 
    can :read, Movie   
  end
end
