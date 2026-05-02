export type WasmModule = {
    __indirect_function_table: { maximum: number, minimum: number, [number]: (...any) -> (...any) },
    memory:                    { maximum: number, [number]: buffer },
    [string]:                  (...any) -> (...any),

    --// guranteed to exist functions
    malloc: (number) -> (number),
    free:   (number) -> (),
    strlen: (number) -> (number),
}

return true