defmodule RegistryHelper do
  def get_user_pid(username) do
		case Registry.lookup(Registry.TwitterRegistry, username) do
      [] -> nil
      [{pid, _value}] -> pid
    end
	end

  def get_simulator_pid(simulator_number) do
    simulator_name = "simulator_"<>to_string(simulator_number)
    case Registry.lookup(Registry.TwitterRegistry, simulator_name) do
      [] -> nil
      [{pid, _value}] -> pid
    end
  end

end
