Solution of 555 enable
==============================================================================

d V_CONT / dt = I_C29 / C29

Kirchoff current law (KCL):
I_C29 = I_pullup - I_pulldown + I_R44

I_pullup = (V_CC - V_CONT) / Rpullup
I_pulldown =  V_CONT / Rpulldown

I_R44 = (V_mix - V_CONT)/ R44
-> V_mix = V_CONT + I_R44 * R44

I_SQ = (V_SQ - V_mix) / R46 = (V_SQ - V_CONT - I_R44 * R44) / R46
I_EN = (V_EN - V_mix) / R45 = (V_EN - V_CONT - I_R44 * R44) / R45
I_R44 = I_SQ + I_EN
      = (V_SQ - V_CONT - I_R44 * R44) / R46 + (V_EN - V_CONT - I_R44 * R44) / R45
      = V_SQ / R46 + V_EN / R45 - (V_CONT - I_R44 * R44) * (R45 + R46) / (R45 * R46)
Abbreviation: Rdivider = (R45 * R46) / (R45 + R46)
      = V_SQ / R46 + V_EN / R45 - (V_CONT - I_R44 * R44) / Rdivider

Solve for I_R44:
I_R44 + I_R44 * R44 / Rdivider = V_SQ / R46 + V_EN / R45 - V_CONT / Rdivider
Abbreviation: f = (1 + R44 / Rdivider) (=sligthly larger 1)
I_R44 * f = V_SQ / R46 + V_EN / R45 - V_CONT / Rdivider
I_R44 = V_SQ /(f * R46) + V_EN / (f * R45) - V_CONT / (f * Rdivider)

Insert currents into equation of I_C29:

I_C29 = (V_CC - V_CONT) / Rpullup
   - V_CONT / Rpulldown
   + V_SQ / (f * R46) + V_EN / (f * R45) - V_CONT / (f * Rdivider)
= V_CC / Rpullup + V_SQ  / (f * R46) + V_EN / (f * R45)
  - V_CONT * (1/Rpullup + 1/Rpulldown + 1/(f * Rdivider))

In top equation:
d V_CONT / dt = -V_CONT / C29 * 1/(1/Rpullup + 1/Rpulldown + 1/(f * Rdivider))
   + V_CC /(Rpullup * C29)
   + V_SQ /(f * R46 * C29)
   + V_EN /(f * R45 * C29)

Basically, the time constant is given by the capacitance and the parallel resistance to all current sinks
(i.e. voltage sources).

Explicit values:

```python
R44 = 1.2e3
R45 = 10e3
R46 = 12e3
C29 = 3.3e-6
Rpullup = 5e3
Rpulldown = 10e3
Rdivider =  1/(1/R46 + 1/R45)
f = (1 + R44 / Rdivider)
f * Rdivider = Rdivider * (1 + R44 / Rdivider)
 = Rdivider + R44 = R44 + R45//R46

Dynamic system in ABCD notation:

dx/dt = A * x + B * u
y = C * x + D * u

A = -(1 / C29) * (1/Rpullup + 1/Rpulldown + 1/(R44 + R45//R46))
B = [1/ (Rpullup * C29), 1/(f * R46 * C29), 1/(f * R45 * C29)]
```

Discretize by Euler method
------------------------------------------------------------------------------

V_CONT_next = V_CONT * (1 - dt * A)
   + V_CC * dt * B[0]
   + V_SQ * dt * B[1]
   + V_EN * dt * B[2]

```python
dt = 1/96e3

print(dt * B[0])  # 0.0006313131313131313
print(dt * B[1])  # 0.00021561240823535905
print(dt * B[2])  # 0.0002587348898824308
print(1 + dt * A)  # 0.9985786830049125
```

Exact solution
------------------------------------------------------------------------------

```python
dt = 1/96e3

A_disc = math.exp(dt * A)
B_disc = [b * (A_disc - 1) / A for b in B]

print(B_disc[0])  # 0.000630864695753267
print(B_disc[1])  # 0.00021545925401409395
print(B_disc[2])  # 0.00025855110481691273
print(A_disc)  # 0.9985796925975391
```

This is a bit disappointing, it seems to not make a big difference. Differences are really not significant: for B values it is clear that 4% resistor variation is much bigger.
For (1 - A), the difference is also less than a percent.
Maybe this should not be so surprising because the sample rate is very much higher than all frequencies involved.

More surpising is that the A-parameter is quite different from the one calculated by anasymod (0.9988949512946891)

Try again for 48 kHz:

```python
dt = 1/48e3

print("Euler method")
print(dt * B[0])  # 0.0012626262626262625
print(dt * B[1])  # 0.0004312248164707181
print(dt * B[2])  # 0.0005174697797648616
print(1 + dt * A)  # 0.9971573660098251

A_disc = math.exp(dt * A)
B_disc = [b * (A_disc - 1) / A for b in B]

print("\nExacter discretization")
print(B_disc[0])  # 0.0012608333697092253
print(B_disc[1])  # 0.0004306124896547901
print(B_disc[2])  # 0.000516734987585748
print(A_disc)  # 0.9971614024681956
```