require "test_helper"

class InstanceTest < ActiveSupport::TestCase
  test "environment variables win over the revision file and git" do
    without_env do
      with_env("APP_VERSION" => "v9.9.9", "APP_COMMIT" => "abc1234") do
        stubbing(Instance, :revision_file, "rev-file") do
          stubbing(Instance, :git_describe, "v0-gdeadbee") do
            stubbing(Instance, :git_commit, "deadbee") do
              assert_equal "v9.9.9", Instance.version
              assert_equal "abc1234", Instance.commit
            end
          end
        end
      end
    end
  end

  test "the REVISION file is the next fallback" do
    without_env do
      stubbing(Instance, :revision_file, "rev-file") do
        stubbing(Instance, :git_describe, "v0-gdeadbee") do
          stubbing(Instance, :git_commit, "deadbee") do
            assert_equal "rev-file", Instance.version
            assert_equal "rev-file", Instance.commit
          end
        end
      end
    end
  end

  test "git is the last resort" do
    without_env do
      stubbing(Instance, :revision_file, nil) do
        stubbing(Instance, :git_describe, "v1.2.3-4-gabc1234") do
          stubbing(Instance, :git_commit, "abc1234") do
            assert_equal "v1.2.3-4-gabc1234", Instance.version
            assert_equal "abc1234", Instance.commit
          end
        end
      end
    end
  end

  test "reports unknown only when nothing is available" do
    without_env do
      stubbing(Instance, :revision_file, nil) do
        stubbing(Instance, :git_describe, nil) do
          stubbing(Instance, :git_commit, nil) do
            assert_equal "unknown", Instance.version
            assert_equal "unknown", Instance.commit
          end
        end
      end
    end
  end

  private

  def without_env
    previous = %w[APP_VERSION APP_COMMIT GIT_REVISION].index_with { |key| ENV[key] }
    previous.each_key { |key| ENV.delete(key) }
    yield
  ensure
    previous.each { |key, value| ENV[key] = value }
  end

  def with_env(values)
    previous = values.keys.index_with { |key| ENV[key] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    previous.each { |key, value| ENV[key] = value }
  end

  def stubbing(receiver, method_name, value)
    original = receiver.method(method_name)
    receiver.define_singleton_method(method_name) { value }
    yield
  ensure
    receiver.define_singleton_method(method_name, original)
  end
end
