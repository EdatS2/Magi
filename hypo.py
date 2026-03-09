x=200
inleg=2

for i in range(0,300):
    y=x * 1.0366 - 12 * inleg * 1.02 ** i
    x=y
    if x < 0:
        print("Afbetaald in ", i - 1, " Inflatie punt ", 1.02 ** i)
        break
    print(x)

