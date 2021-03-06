require "spec_helper"

describe "Bundler.setup" do
  it "uses BUNDLE_GEMFILE to locate the gemfile if present" do
    gemfile <<-G
      source "file://#{gem_repo1}"
      gem "rack"
    G

    gemfile bundled_app('4realz'), <<-G
      source "file://#{gem_repo1}"
      gem "activesupport", "2.3.5"
    G

    ENV['BUNDLE_GEMFILE'] = bundled_app('4realz').to_s
    bundle :install

    should_be_installed "activesupport 2.3.5"
  end

  it "prioritizes gems in BUNDLE_PATH over gems in GEM_HOME" do
    ENV['BUNDLE_PATH'] = bundled_app('.bundle').to_s
    install_gemfile <<-G
      source "file://#{gem_repo1}"
      gem "rack", "1.0.0"
    G

    build_gem "rack", "1.0", :to_system => true do |s|
      s.write "lib/rack.rb", "RACK = 'FAIL'"
    end

    should_be_installed "rack 1.0.0"
  end

  describe "cripping rubygems" do
    describe "by replacing #gem" do
      before :each do
        install_gemfile <<-G
          source "file://#{gem_repo1}"
          gem "rack", "0.9.1"
        G
      end

      it "replaces #gem but raises when the gem is missing" do
        run <<-R
          begin
            gem "activesupport"
            puts "FAIL"
          rescue LoadError
            puts "WIN"
          end
        R

        out.should == "WIN"
      end

      it "replaces #gem but raises when the version is wrong" do
        run <<-R
          begin
            gem "rack", "1.0.0"
            puts "FAIL"
          rescue LoadError
            puts "WIN"
          end
        R

        out.should == "WIN"
      end
    end

    describe "by hiding system gems" do
      before :each do
        system_gems "activesupport-2.3.5"
        install_gemfile <<-G
          source "file://#{gem_repo1}"
          gem "yard"
        G
      end

      it "removes system gems from Gem.source_index" do
        run "require 'yard'"
        out.should == "yard-1.0"
      end
    end
  end

  describe "with paths" do
    it "activates the gems in the path source" do
      system_gems "rack-1.0.0"

      build_lib "rack", "1.0.0" do |s|
        s.write "lib/rack.rb", "puts 'WIN'"
      end

      gemfile <<-G
        path "#{lib_path('rack-1.0.0')}"
        source "file://#{gem_repo1}"
        gem "rack"
      G

      run "require 'rack'"
      out.should == "WIN"
    end
  end

  describe "with git" do
    it "provides a useful exception when the git repo is not checked out yet" do
      build_git "rack", "1.0.0"

      gemfile <<-G
        gem "foo", :git => "#{lib_path('rack-1.0.0')}"
      G

      run "1", :expect_err => true
      err.should include("#{lib_path('rack-1.0.0')} (at master) is not checked out. Please run `bundle install`")
    end
  end

  describe "when excluding groups" do
    it "doesn't change the resolve if --without is used" do
      install_gemfile <<-G, :without => :rails
        source "file://#{gem_repo1}"
        gem "activesupport"

        group :rails do
          gem "rails", "2.3.2"
        end
      G

      install_gems "activesupport-2.3.5"

      should_be_installed "activesupport 2.3.2", :groups => :default
    end

    it "remembers --without and does not bail on bare Bundler.setup" do
      install_gemfile <<-G, :without => :rails
        source "file://#{gem_repo1}"
        gem "activesupport"

        group :rails do
          gem "rails", "2.3.2"
        end
      G

      install_gems "activesupport-2.3.5"

      should_be_installed "activesupport 2.3.2"
    end

    it "remembers --without and does not include groups passed to Bundler.setup" do
      install_gemfile <<-G, :without => :rails
        source "file://#{gem_repo1}"
        gem "activesupport"

        group :rack do
          gem "rack"
        end

        group :rails do
          gem "rails", "2.3.2"
        end
      G

      should_not_be_installed "activesupport 2.3.2", :groups => :rack
      should_be_installed "rack 1.0.0", :groups => :rack
    end
  end

  # Rubygems returns loaded_from as a string
  it "has loaded_from as a string on all specs" do
    build_git "foo"
    build_git "no-gemspec", :gemspec => false

    install_gemfile <<-G
      source "file://#{gem_repo1}"
      gem "rack"
      gem "foo", :git => "#{lib_path('foo-1.0')}"
      gem "no-gemspec", "1.0", :git => "#{lib_path('no-gemspec-1.0')}"
    G

    run <<-R
      Gem.loaded_specs.each do |n, s|
        puts "FAIL" unless String === s.loaded_from
      end
    R

    out.should be_empty
  end

  it "ignores empty gem paths" do
    install_gemfile <<-G
      source "file://#{gem_repo1}"
      gem "rack"
    G

    ENV["GEM_HOME"] = ""
    bundle %{exec ruby -e "require 'set'"}

    err.should be_empty
  end

end
