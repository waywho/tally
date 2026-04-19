FactoryBot.define do
  factory :account do
    sequence(:email) { |n| "user#{n}@example.com" }
    password_hash { RodauthApp.rodauth.allocate.password_hash("password") }
    status { "verified" }
  end
end
