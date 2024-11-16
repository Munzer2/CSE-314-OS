#include <chrono>
#include <iostream>
#include <pthread.h>
#include <semaphore.h>
#include <random>
#include <unistd.h>
#include <vector>
#include <chrono>
#define GALLERY_1_LIM 5
#define corridor_DE_LIM 3
#define Sleep_mul 100

using namespace std; 


int st_cnt = 0;
int prem_cnt = 0;

sem_t gal1_cap; 
sem_t corr_DE_cap; 
pthread_mutex_t stairs[3];
pthread_mutex_t print_lock; 
pthread_mutex_t standLock; 
pthread_mutex_t PremLock; 
pthread_mutex_t PBLock; 
pthread_mutex_t accessLock; 
auto strt = chrono::steady_clock::now(); 



int get_random_number() {
  // Creates a random device for non-deterministic random number generation
  std::random_device rd;
  // Initializes a random number generator using the random device
  std::mt19937 generator(rd());

  // Lambda value for the Poisson distribution
  double lambda = 10000.234;

  // Defines a Poisson distribution with the given lambda
  std::poisson_distribution<int> poissonDist(lambda);

  // Generates and returns a random number based on the Poisson distribution
  return poissonDist(generator);
}


void print_mssg(string mssg) {
    pthread_mutex_lock(&print_lock);
    cout << mssg;
    pthread_mutex_unlock(&print_lock); 
}

class _visitor {
    public:
    int ID; 
    int w,x,y,z; 
    void setID(int id) {ID = id ; } 
}; 

void _init() {
    for(int i = 0 ; i < 3; ++i) pthread_mutex_init(&stairs[i], NULL);
    sem_init(&gal1_cap, 0, GALLERY_1_LIM); 
    sem_init(&corr_DE_cap, 0, corridor_DE_LIM);
    pthread_mutex_init(&print_lock, NULL);
    pthread_mutex_init(&PBLock, NULL);
    pthread_mutex_init(&accessLock, NULL);
    pthread_mutex_init(&standLock, NULL);
    pthread_mutex_init(&PremLock, NULL);
    return; 
}


long get_timestamp() {
    auto now = chrono::steady_clock::now();
    auto elapsed = chrono::duration_cast<chrono::milliseconds>(now - strt);
    return elapsed.count();
}


void Premium(int ID, int _wait) {
    pthread_mutex_lock(&PremLock); 
    prem_cnt++;
    if(prem_cnt == 1) {
        pthread_mutex_lock(&accessLock);
    }
    pthread_mutex_unlock(&PremLock); 

    pthread_mutex_lock(&PBLock); 
    ///Take time using the photo booth.
    print_mssg("Visitor " + to_string(ID) + " is inside the photobooth at timestamp " + to_string(get_timestamp()) + "\n");
    usleep((_wait == 0 ? 2000 : _wait*2000)); 
    pthread_mutex_unlock(&PBLock);

    pthread_mutex_lock(&PremLock); 
    prem_cnt--;
    if(!prem_cnt) pthread_mutex_unlock(&accessLock);
    pthread_mutex_unlock(&PremLock);
    return;  
} 

void Standard(int ID, int _wait) {
    pthread_mutex_lock(&accessLock);
    pthread_mutex_lock(&standLock); 
    st_cnt++; 
    if(st_cnt == 1) {
        pthread_mutex_lock(&PBLock);
    }
    pthread_mutex_unlock(&standLock);
    pthread_mutex_unlock(&accessLock); 
    print_mssg("Visitor " + to_string(ID) + " is inside the photobooth at timestamp " + to_string(get_timestamp()) + "\n");
    ///Take time using the PB
    usleep((_wait == 0 ? 2000 : _wait*2000)); 
    pthread_mutex_lock(&standLock); 
    st_cnt--;
    if(st_cnt == 0) pthread_mutex_unlock(&PBLock); 
    pthread_mutex_unlock(&standLock); 
    return; 
}

void *visitMuseam(void *arg) {
    _visitor *vis = (_visitor *)arg; 
    usleep(get_random_number()%1000 + 2000);
    print_mssg("Visitor " + to_string(vis->ID) + " has arrived at A at timestamp " + to_string(get_timestamp()) + "\n");   
    usleep((vis->w == 0 ? 1000 : vis->w*1000)); 
    pthread_mutex_lock(&stairs[0]);
    print_mssg("Visitor " + to_string(vis->ID) + " is at step-1 at timestamp " + to_string(get_timestamp()) +  "\n");
    usleep(1000); 
    pthread_mutex_lock(&stairs[1]);
    pthread_mutex_unlock(&stairs[0]);
    print_mssg("Visitor " + to_string(vis->ID) + " is at step 2 at timestamp " + to_string(get_timestamp()) + "\n");
    usleep(1000); 
    pthread_mutex_lock(&stairs[2]); 
    pthread_mutex_unlock(&stairs[1]);
    print_mssg("Visitor " + to_string(vis->ID) + " is at step 3 at timestamp " + to_string(get_timestamp()) + "\n");
    usleep(1000);

    sem_wait(&gal1_cap);
    pthread_mutex_unlock(&stairs[2]);   
    print_mssg("Visitor " + to_string(vis->ID) + " is at C (entered Gallery 1) at timestamp " + to_string(get_timestamp()) + "\n");

    usleep((vis->x == 0 ? 1000 : vis->x*1000)); 

    sem_wait(&corr_DE_cap);   
    sem_post(&gal1_cap); 
    print_mssg("Visitor " + to_string(vis->ID) + " is at D (exiting Gallery 1) at timestamp " + to_string(get_timestamp()) + "\n");

    usleep(3000); ///arbitrary delay at the corridor.
    sem_post(&corr_DE_cap);

    print_mssg("Visitor " + to_string(vis->ID) + " is at E (entered Gallery 2) at timestamp " + to_string(get_timestamp()) + "\n");

    usleep((vis->y == 0 ? 1000 : vis->y*1000));

    print_mssg("Visitor " + to_string(vis->ID) + " is about to enter the photobooth at timestamp " + to_string(get_timestamp()) + "\n");

    usleep(1000);

    if(vis->ID <= 1100) { ///standard ticket holder. 
        Standard(vis->ID,vis->w); 
    }  
    else{ ///Premium ticket holder.
        Premium(vis->ID, vis->w); 
    }
    return NULL; 
}




int main(int argc, char *argv[]) {
    int N , M, w, x, y, z; 
    N = atoi(argv[1]),M = atoi(argv[2]),w = atoi(argv[3]),x = atoi(argv[4]),y = atoi(argv[5]), z = atoi(argv[6]); 
    _init();
    pthread_t threads[N+M]; 
    vector<_visitor> all_visitors(N+M); 
    for(int i = 0 ; i < N+M ; ++i) {
        int _rand = (i < N ? 1001 + i: 2001 + i - N);
        all_visitors[i].setID(_rand);
        all_visitors[i].w = w; 
        all_visitors[i].x = x; 
        all_visitors[i].y = y; 
        all_visitors[i].z = z; 
    }

    for(int i = 0; i < N+M; ++i) {
        pthread_create(&threads[i], NULL, visitMuseam, &all_visitors[i]);
        // int rand_delay = get_random_number()%3 + 1;
        // sleep(rand_delay); 
        // sleep(1);
    }

    for(int i = 0 ; i < N+M; ++i) {
        pthread_join(threads[i], NULL);
    }
    return 0;  
}