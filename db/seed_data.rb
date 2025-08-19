# Seed data for the Rails application
# This file contains static data used to seed the database

module SeedData
  USERS = [
    { name: "Jane Doe", email: "jane@example.com" },
  ].freeze

  ARTICLES = [
    {
      title: "Getting Started with Ruby on Rails",
      body: "Ruby on Rails is a server-side web application framework written in Ruby. It is a model-view-controller framework, providing default structures for a database, a web service, and web pages. This article will guide you through the basics of setting up and building your first Rails application."
    }
   ].freeze
end