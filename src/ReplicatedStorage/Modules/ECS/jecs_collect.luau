
type Signal<T...> = { [any]: any}
local function collect<T...>(event: Signal<T...>)
    local storage = {}
    local mt = {}
    local iter = function()
        local n = #storage
        return function()
            if n <= 0 then
                mt.__iter = nil
                return nil
            end

            n -= 1
            return n + 1, unpack(table.remove(storage, 1) :: any)
        end
    end
    local disconnect = event:Connect(function(...)
        table.insert(storage, { ... })
        mt.__iter = iter
    end)

    setmetatable(storage, mt)
    return (storage :: any) :: () -> (number, T...), function()
        disconnect()
    end
end

return collect