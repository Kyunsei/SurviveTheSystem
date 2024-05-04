def lerp_n(values, t):
    n = len(values)
    segment = int(t * (n - 1))
    t_in_segment = (t * (n - 1)) - segment

    if segment == n - 1:
        return values[-1]
    else:
        return (1 - t_in_segment) * values[segment] + t_in_segment * values[segment + 1]

# Example usage:
values = [0, 1, 4, 7, 100]
t = 0.4
result = lerp_n(values, t)
print("Interpolated value:", result)


print(0.5/4)